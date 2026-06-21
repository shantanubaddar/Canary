import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../core/canary_models.dart';
import '../metadata/metadata_service.dart';

enum DuplicateImportPolicy { skip, replace, keepBoth }

class LibraryController {
  LibraryController({MetadataService? metadataService})
    : _metadataService = metadataService ?? MetadataService() {
    _tracks = _loadPersistedTracks() ?? [];
    _rebuildPlaylists();
  }

  final MetadataService _metadataService;
  final _tracksController = StreamController<List<CanaryTrack>>.broadcast();
  final _playlistsController = StreamController<List<AutoPlaylist>>.broadcast();

  late List<CanaryTrack> _tracks;
  List<AutoPlaylist> _playlists = [];
  final Map<String, AlbumLook> _albumLooks = {};

  Stream<List<CanaryTrack>> get tracks => _tracksController.stream;
  Stream<List<AutoPlaylist>> get playlists => _playlistsController.stream;
  List<CanaryTrack> get currentTracks => List.unmodifiable(_tracks);
  List<AutoPlaylist> get currentPlaylists => List.unmodifiable(_playlists);
  CoverCachePolicy get coverPolicy => _metadataService.coverPolicy;

  void emit() {
    _tracksController.add(currentTracks);
    _playlistsController.add(currentPlaylists);
  }

  Future<List<ImportCandidate>> prepareImportCandidates(List<String> paths) {
    return Future.wait(paths.map(_metadataService.candidateFromFile));
  }

  CanaryTrack? duplicateForCandidate(ImportCandidate candidate) {
    final draft = candidate.draft;
    final title = _normalize(draft?.title ?? candidate.currentTitle);
    final artist = _normalize(draft?.artist ?? candidate.currentArtist);
    final path = candidate.filePath;
    for (final track in _tracks) {
      if (track.localPath == path) return track;
      if (_normalize(track.title) == title &&
          _normalize(track.artist) == artist) {
        return track;
      }
    }
    return null;
  }

  Future<AlbumDraft> prepareAlbumDraft(String playlistUrl) {
    return _metadataService.albumDraftFromYoutubePlaylist(playlistUrl);
  }

  Future<MetadataDraft> previewMetadata({
    required String songQuery,
    required String youtubeUrl,
  }) {
    return _metadataService.draftFromInput(
      songQuery: songQuery,
      youtubeUrl: youtubeUrl,
    );
  }

  Future<List<MetadataDraft>> previewMetadataOptions({
    required String songQuery,
    String youtubeUrl = '',
  }) {
    return _metadataService.draftOptionsFromInput(
      songQuery: songQuery,
      youtubeUrl: youtubeUrl,
    );
  }

  AlbumLook albumLookFor({
    required String albumId,
    required String albumTitle,
    required String artist,
    required String? coverKey,
  }) {
    final existing = _albumLooks[albumId];
    if (existing != null && existing.sourceKey == coverKey) return existing;
    final look = _buildAlbumLook(
      albumId,
      '$albumTitle|$artist|${coverKey ?? ''}',
      sourceKey: coverKey,
    );
    _albumLooks[albumId] = look;
    unawaited(
      _refreshAlbumLookFromCover(
        albumId: albumId,
        albumTitle: albumTitle,
        artist: artist,
        coverKey: coverKey,
      ),
    );
    unawaited(_saveTracks());
    return look;
  }

  Future<void> _refreshAlbumLookFromCover({
    required String albumId,
    required String albumTitle,
    required String artist,
    required String? coverKey,
  }) async {
    if (coverKey == null || coverKey.trim().isEmpty) return;
    final file = File(coverKey.replaceFirst('file://', ''));
    if (!await file.exists()) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        FileImage(file),
        size: const Size(80, 80),
        maximumColorCount: 20,
      );
      _albumLooks[albumId] = _albumLookFromPalette(
        albumId: albumId,
        sourceKey: coverKey,
        seed: '$albumTitle|$artist|$coverKey',
        palette: palette,
      );
      await _saveTracks();
      emit();
    } catch (_) {
      // Keep the neutral fallback if image decoding fails.
    }
  }

  Future<MetadataDraft?> previewAlbumMetadata({
    required String title,
    required String artist,
    required String album,
    MetadataDraft? fallback,
  }) {
    return _metadataService.draftFromAlbumContext(
      title: title,
      artist: artist,
      album: album,
      fallback: fallback,
    );
  }

  Future<CanaryTrack> addSong({
    required String songQuery,
    required String youtubeUrl,
  }) async {
    final draft = await previewMetadata(
      songQuery: songQuery,
      youtubeUrl: youtubeUrl,
    );
    final track = _trackFromDraft(
      draft,
      localPath: null,
      sourceKind: youtubeUrl.trim().isNotEmpty
          ? CanarySourceKind.youtubeLink
          : CanarySourceKind.manualSearch,
      youtubeUrl: youtubeUrl.trim().isEmpty ? null : youtubeUrl.trim(),
    );
    _tracks = [track, ..._tracks];
    _rebuildPlaylists();
    unawaited(_saveTracks());
    emit();
    return track;
  }

  Future<void> acceptImportCandidates(
    List<ImportCandidate> candidates, {
    DuplicateImportPolicy duplicatePolicy = DuplicateImportPolicy.keepBoth,
  }) async {
    final existingIdsToReplace = <String>{};
    final accepted = <ImportCandidate>[];
    for (final candidate in candidates) {
      final duplicate = duplicateForCandidate(candidate);
      if (duplicate == null ||
          duplicatePolicy == DuplicateImportPolicy.keepBoth) {
        accepted.add(candidate);
        continue;
      }
      if (duplicatePolicy == DuplicateImportPolicy.replace) {
        existingIdsToReplace.add(duplicate.id);
        accepted.add(candidate);
      }
    }
    final imported = accepted.map((candidate) {
      final draft =
          candidate.draft ??
          MetadataDraft(
            title: candidate.currentTitle,
            artist: candidate.currentArtist,
            album: 'Single',
            genre: 'Unsorted',
            confidence: .30,
            coverUrl: null,
            sourceLabel: 'Current file metadata',
            artistImageUrl: null,
          );
      return _trackFromDraft(
        draft,
        localPath: candidate.filePath,
        sourceKind: CanarySourceKind.localFile,
      );
    }).toList();
    _tracks = [
      ...imported,
      ..._tracks.where((track) => !existingIdsToReplace.contains(track.id)),
    ];
    _rebuildPlaylists();
    unawaited(_saveTracks());
    emit();
  }

  Future<void> unlinkTrack(String trackId) async {
    _tracks = _tracks.where((track) => track.id != trackId).toList();
    _rebuildPlaylists();
    unawaited(_saveTracks());
    emit();
  }

  Future<void> updateAlbumCover({
    required String albumId,
    required String imagePath,
  }) async {
    final file = File(imagePath);
    final bytes = await file.exists() ? await file.length() : 0;
    final cover = CoverAsset(
      id: 'cover-${DateTime.now().microsecondsSinceEpoch}-${imagePath.hashCode}',
      sourceUrl: imagePath,
      localPath: imagePath,
      width: coverPolicy.maxDimension,
      height: coverPolicy.maxDimension,
      bytes: bytes,
      state: CoverCacheState.cached,
    );
    String? albumTitle;
    String? artist;
    _tracks = _tracks.map((track) {
      if (_albumKey(track.album) != albumId) return track;
      albumTitle ??= track.displayAlbum;
      artist ??= track.displayArtist;
      return track.copyWith(cover: cover);
    }).toList();
    _albumLooks.remove(albumId);
    if (albumTitle != null && artist != null) {
      unawaited(
        _refreshAlbumLookFromCover(
          albumId: albumId,
          albumTitle: albumTitle!,
          artist: artist!,
          coverKey: imagePath,
        ),
      );
    }
    _rebuildPlaylists();
    unawaited(_saveTracks());
    emit();
  }

  Future<void> moveTracksToAlbum({
    required String albumId,
    required String albumTitle,
    required List<String> trackIds,
  }) async {
    final selected = trackIds.toSet();
    _tracks = _tracks.map((track) {
      if (!selected.contains(track.id)) return track;
      return track.copyWith(album: albumTitle);
    }).toList();
    _albumLooks.remove(albumId);
    _rebuildPlaylists();
    unawaited(_saveTracks());
    emit();
  }

  Future<void> deleteAlbum(String albumId) async {
    _tracks = _tracks
        .where((track) => _albumKey(track.album) != albumId)
        .toList();
    _albumLooks.remove(albumId);
    _rebuildPlaylists();
    unawaited(_saveTracks());
    emit();
  }

  Future<void> acceptAlbumDraft(AlbumDraft draft) async {
    final mapped = draft.tracks
        .where((track) => track.mappedFilePath != null)
        .map((track) {
          final metadata = MetadataDraft(
            title: track.title,
            artist: track.artist,
            album: draft.title,
            genre: 'Unsorted',
            confidence: .68,
            coverUrl: draft.coverUrl,
            sourceLabel: 'YouTube playlist mapping',
            artistImageUrl: null,
          );
          return _trackFromDraft(
            metadata,
            localPath: track.mappedFilePath,
            sourceKind: CanarySourceKind.localFile,
          );
        })
        .toList();
    _tracks = [...mapped, ..._tracks];
    _rebuildPlaylists();
    unawaited(_saveTracks());
    emit();
  }

  CanaryTrack _trackFromDraft(
    MetadataDraft draft, {
    required String? localPath,
    required CanarySourceKind sourceKind,
    String? youtubeUrl,
  }) {
    return CanaryTrack(
      id: 'track-${DateTime.now().microsecondsSinceEpoch}-${draft.title.hashCode}',
      title: draft.title,
      artist: draft.artist,
      album: draft.album,
      genre: draft.genre,
      duration: const Duration(minutes: 3, seconds: 24),
      sourceKind: sourceKind,
      localPath: localPath,
      youtubeUrl: youtubeUrl,
      artistImageUrl: draft.artistImageUrl,
      cover: CoverAsset(
        id: 'cover-${DateTime.now().microsecondsSinceEpoch}-${draft.title.hashCode}',
        sourceUrl: draft.coverUrl,
        localPath: null,
        width: coverPolicy.maxDimension,
        height: coverPolicy.maxDimension,
        bytes: 0,
        state: draft.coverUrl == null
            ? CoverCacheState.missing
            : CoverCacheState.queued,
      ),
      addedAt: DateTime.now(),
    );
  }

  void _rebuildPlaylists() {
    final byGenre = <String, List<String>>{};
    for (final track in _tracks) {
      byGenre.putIfAbsent(track.genre, () => []).add(track.id);
    }
    _playlists = byGenre.entries
        .map(
          (entry) => AutoPlaylist(
            id: 'genre-${entry.key.toLowerCase().replaceAll(' ', '-')}',
            name: entry.key == 'Unsorted'
                ? 'Needs a Genre'
                : '${entry.key} Mix',
            reason: entry.key == 'Unsorted'
                ? 'Tracks Canary could not classify confidently yet.'
                : 'Auto-built from ${entry.key} tagged songs.',
            trackIds: entry.value,
            accent: _genreAccent(entry.key),
          ),
        )
        .toList();
  }

  int _genreAccent(String genre) {
    return switch (genre) {
      'Hip-Hop' => 0xFFFFD54F,
      'R&B' => 0xFFFF7AAE,
      'Electronic' => 0xFF65D6CE,
      'Lo-Fi' => 0xFFA8E063,
      _ => 0xFFFFC857,
    };
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _albumKey(String value) => _normalize(value);

  File get _libraryFile {
    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    return File('$home/.local/share/canary/library.json');
  }

  List<CanaryTrack>? _loadPersistedTracks() {
    try {
      final file = _libraryFile;
      if (!file.existsSync()) return null;
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final looks = data['albumLooks'];
      if (looks is List) {
        _albumLooks
          ..clear()
          ..addEntries(
            looks.whereType<Map<String, dynamic>>().map((look) {
              final albumLook = _albumLookFromJson(look);
              return MapEntry(albumLook.id, albumLook);
            }),
          );
      }
      final tracks = data['tracks'];
      if (tracks is! List) return null;
      return tracks
          .whereType<Map<String, dynamic>>()
          .map(_trackFromJson)
          .where((track) => !_isRemovedLocalTrack(track))
          .where((track) => !_isPlaceholderTrack(track))
          .toList();
    } catch (_) {
      return null;
    }
  }

  bool _isRemovedLocalTrack(CanaryTrack track) {
    return track.sourceKind == CanarySourceKind.localFile &&
        (track.localPath == null || track.localPath!.trim().isEmpty);
  }

  bool _isPlaceholderTrack(CanaryTrack track) {
    return track.id.startsWith('seed-') ||
        track.artist == 'Canary Lab' ||
        track.artist == 'HyprWave Reference' ||
        track.artist == 'PaperPlane Lessons';
  }

  Future<void> _saveTracks() async {
    try {
      final file = _libraryFile;
      final parent = file.parent;
      if (!await parent.exists()) await parent.create(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(
        encoder.convert({
          'version': 1,
          'savedAt': DateTime.now().toIso8601String(),
          'albumLooks': _albumLooks.values.map(_albumLookToJson).toList(),
          'tracks': _tracks.map(_trackToJson).toList(),
        }),
      );
    } catch (_) {
      // Persistence should never break the live library UI.
    }
  }

  Map<String, dynamic> _trackToJson(CanaryTrack track) {
    return {
      'id': track.id,
      'title': track.title,
      'artist': track.artist,
      'album': track.album,
      'genre': track.genre,
      'durationMs': track.duration.inMilliseconds,
      'sourceKind': track.sourceKind.name,
      'localPath': track.localPath,
      'youtubeUrl': track.youtubeUrl,
      'artistImageUrl': track.artistImageUrl,
      'addedAt': track.addedAt.toIso8601String(),
      'cover': {
        'id': track.cover.id,
        'sourceUrl': track.cover.sourceUrl,
        'localPath': track.cover.localPath,
        'width': track.cover.width,
        'height': track.cover.height,
        'bytes': track.cover.bytes,
        'state': track.cover.state.name,
      },
    };
  }

  Map<String, dynamic> _albumLookToJson(AlbumLook look) {
    return {
      'id': look.id,
      'sourceKey': look.sourceKey,
      'background': look.background,
      'primary': look.primary,
      'secondary': look.secondary,
      'text': look.text,
    };
  }

  AlbumLook _albumLookFromJson(Map<String, dynamic> data) {
    return AlbumLook(
      id:
          data['id'] as String? ??
          'album-look-${DateTime.now().microsecondsSinceEpoch}',
      sourceKey: data['sourceKey'] as String?,
      background: data['background'] as int? ?? 0xFF201A12,
      primary: data['primary'] as int? ?? 0xFFFFD447,
      secondary: data['secondary'] as int? ?? 0xFF8A6B38,
      text: data['text'] as int? ?? 0xFFFFFFFF,
    );
  }

  AlbumLook _buildAlbumLook(
    String albumId,
    String seed, {
    required String? sourceKey,
  }) {
    final hash = seed.hashCode.abs();
    final shade = 18 + (hash % 16);
    final primaryShade = 170 + (hash % 42);
    return AlbumLook(
      id: albumId,
      sourceKey: sourceKey,
      background: Color.fromARGB(255, shade, shade, shade).toARGB32(),
      primary: Color.fromARGB(
        255,
        primaryShade,
        primaryShade,
        primaryShade,
      ).toARGB32(),
      secondary: const Color(0xFF464646).toARGB32(),
      text: 0xFFFFFFFF,
    );
  }

  AlbumLook _albumLookFromPalette({
    required String albumId,
    required String? sourceKey,
    required String seed,
    required PaletteGenerator palette,
  }) {
    final dominant = palette.dominantColor?.color;
    final vibrant =
        palette.vibrantColor?.color ?? palette.lightVibrantColor?.color;
    final muted = palette.mutedColor?.color ?? palette.darkMutedColor?.color;
    final base = dominant ?? muted ?? vibrant;
    if (base == null) {
      return _buildAlbumLook(albumId, seed, sourceKey: sourceKey);
    }

    final baseHsl = HSLColor.fromColor(base);
    final vibrantHsl = HSLColor.fromColor(vibrant ?? base);
    final mutedHsl = HSLColor.fromColor(muted ?? base);
    final monochrome = baseHsl.saturation < .14 && vibrantHsl.saturation < .20;

    final backgroundColor = monochrome
        ? HSLColor.fromAHSL(
            1,
            baseHsl.hue,
            .02,
            baseHsl.lightness.clamp(.07, .16),
          ).toColor()
        : HSLColor.fromAHSL(
            1,
            baseHsl.hue,
            (baseHsl.saturation * .54).clamp(.18, .42),
            baseHsl.lightness.clamp(.10, .22),
          ).toColor();
    final primaryColor = monochrome
        ? HSLColor.fromAHSL(1, baseHsl.hue, .02, .78).toColor()
        : HSLColor.fromAHSL(
            1,
            vibrantHsl.hue,
            (vibrantHsl.saturation * 1.16).clamp(.42, .82),
            vibrantHsl.lightness.clamp(.48, .68),
          ).toColor();
    final secondaryColor = monochrome
        ? HSLColor.fromAHSL(1, baseHsl.hue, .02, .28).toColor()
        : HSLColor.fromAHSL(
            1,
            mutedHsl.hue,
            (mutedHsl.saturation * .72).clamp(.16, .52),
            mutedHsl.lightness.clamp(.20, .38),
          ).toColor();
    return AlbumLook(
      id: albumId,
      sourceKey: sourceKey,
      background: backgroundColor.toARGB32(),
      primary: primaryColor.toARGB32(),
      secondary: secondaryColor.toARGB32(),
      text: 0xFFFFFFFF,
    );
  }

  CanaryTrack _trackFromJson(Map<String, dynamic> data) {
    final cover = data['cover'] is Map<String, dynamic>
        ? data['cover'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return CanaryTrack(
      id:
          data['id'] as String? ??
          'track-${DateTime.now().microsecondsSinceEpoch}',
      title: data['title'] as String? ?? 'Untitled Track',
      artist: data['artist'] as String? ?? 'Unknown Artist',
      album: data['album'] as String? ?? 'Single',
      genre: data['genre'] as String? ?? 'Unsorted',
      duration: Duration(
        milliseconds:
            data['durationMs'] as int? ??
            const Duration(minutes: 3, seconds: 24).inMilliseconds,
      ),
      sourceKind: CanarySourceKind.values.firstWhere(
        (kind) => kind.name == data['sourceKind'],
        orElse: () => CanarySourceKind.localFile,
      ),
      localPath: data['localPath'] as String?,
      youtubeUrl: data['youtubeUrl'] as String?,
      artistImageUrl: data['artistImageUrl'] as String?,
      cover: CoverAsset(
        id:
            cover['id'] as String? ??
            'cover-${DateTime.now().microsecondsSinceEpoch}',
        sourceUrl: cover['sourceUrl'] as String?,
        localPath: cover['localPath'] as String?,
        width: cover['width'] as int? ?? coverPolicy.maxDimension,
        height: cover['height'] as int? ?? coverPolicy.maxDimension,
        bytes: cover['bytes'] as int? ?? 0,
        state: CoverCacheState.values.firstWhere(
          (state) => state.name == cover['state'],
          orElse: () => CoverCacheState.cached,
        ),
      ),
      addedAt:
          DateTime.tryParse(data['addedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  void dispose() {
    _tracksController.close();
    _playlistsController.close();
  }
}
