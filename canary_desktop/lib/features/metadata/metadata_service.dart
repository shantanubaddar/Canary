import 'dart:convert';
import 'dart:io';

import '../../core/canary_models.dart';

class CoverCachePolicy {
  const CoverCachePolicy({
    this.maxDimension = 640,
    this.jpegQuality = 82,
    this.maxBytes = 220 * 1024,
  });

  final int maxDimension;
  final int jpegQuality;
  final int maxBytes;

  String get label =>
      '${maxDimension}px / q$jpegQuality / ${(maxBytes / 1024).round()}KB cap';
}

class MetadataService {
  MetadataService({this.coverPolicy = const CoverCachePolicy()});

  static const _acoustIdDemoClient = 'bbOGDCoy0Aw';

  final CoverCachePolicy coverPolicy;
  final Map<String, String?> _artistImageCache = {};
  DateTime _lastMusicBrainzRequest = DateTime.fromMillisecondsSinceEpoch(0);

  Future<ImportCandidate> candidateFromFile(String path) async {
    final fileName = path.split(Platform.pathSeparator).last;
    final stem = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final parsed = _splitArtistAndTitle(
      _cleanYoutubeTitle(stem.replaceAll('_', ' ')),
    );
    final embedded = await _readEmbeddedMetadata(path);
    final currentTitle = _cleanYoutubeTitle(embedded.title ?? parsed.$2);
    final currentArtist = _cleanArtistName(embedded.artist ?? parsed.$1);
    final candidate = ImportCandidate(
      id: 'import-${DateTime.now().microsecondsSinceEpoch}-$fileName',
      filePath: path,
      fileName: fileName,
      currentTitle: currentTitle,
      currentArtist: currentArtist,
      draft: null,
      status: embedded.hasUsefulTags
          ? 'Read embedded file metadata'
          : 'Read filename metadata',
    );
    final embeddedCover = await _extractEmbeddedCover(path);
    final fingerprintDraft = await _draftFromAudioFingerprint(
      path,
      embedded: embedded,
    );
    final onlineDraft =
        fingerprintDraft ??
        await draftFromInput(
          songQuery: '${candidate.currentArtist} - ${candidate.currentTitle}',
          youtubeUrl: '',
        );
    var draft = embedded.toDraft(onlineDraft: onlineDraft) ?? onlineDraft;
    if (embeddedCover != null) {
      draft = draft.copyWith(
        coverUrl: embeddedCover,
        sourceLabel: '${draft.sourceLabel} + embedded cover',
      );
    }
    return candidate.copyWith(draft: draft, status: 'Ready for confirmation');
  }

  Future<MetadataDraft> draftFromInput({
    required String songQuery,
    required String youtubeUrl,
  }) async {
    final trimmedUrl = youtubeUrl.trim();
    final trimmedQuery = songQuery.trim();
    if (trimmedUrl.isNotEmpty) {
      return _draftFromYoutubeLink(trimmedUrl, fallbackQuery: trimmedQuery);
    }
    return _draftFromBestSearchProvider(trimmedQuery);
  }

  Future<List<MetadataDraft>> draftOptionsFromInput({
    required String songQuery,
    required String youtubeUrl,
    int limit = 5,
  }) async {
    final trimmedUrl = youtubeUrl.trim();
    final trimmedQuery = songQuery.trim();
    if (trimmedUrl.isNotEmpty) {
      return [
        await _draftFromYoutubeLink(trimmedUrl, fallbackQuery: trimmedQuery),
      ];
    }
    final drafts = <MetadataDraft>[];
    drafts.addAll(
      await _draftsFromAppleMusicSearch(trimmedQuery, limit: limit),
    );
    drafts.addAll(await _draftsFromDeezerSearch(trimmedQuery, limit: limit));
    drafts.addAll(await _draftsFromMusicBrainz(trimmedQuery, limit: limit));
    final youtube = await _draftFromYoutubeSearch(trimmedQuery);
    if (youtube != null) drafts.add(youtube);
    return _rankAndLimitDrafts(drafts, limit: limit);
  }

  Future<MetadataDraft?> draftFromAlbumContext({
    required String title,
    required String artist,
    required String album,
    MetadataDraft? fallback,
  }) async {
    final safeTitle = title.trim();
    final safeArtist = artist.trim();
    final safeAlbum = album.trim();
    if (safeAlbum.isEmpty || !_hasAlbumContext(safeAlbum)) return null;
    final query = [
      safeArtist,
      safeAlbum,
    ].where((part) => part.isNotEmpty).join(' ');
    final candidates = <_AlbumMetadataMatch>[];
    candidates.addAll(
      await _albumMatchesFromAppleMusic(
        query,
        targetTitle: safeTitle,
        targetArtist: safeArtist,
        targetAlbum: safeAlbum,
      ),
    );
    candidates.addAll(
      await _albumMatchesFromDeezer(
        query,
        targetTitle: safeTitle,
        targetArtist: safeArtist,
        targetAlbum: safeAlbum,
      ),
    );
    candidates.addAll(
      await _albumMatchesFromMusicBrainz(
        query,
        targetTitle: safeTitle,
        targetArtist: safeArtist,
        targetAlbum: safeAlbum,
      ),
    );
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.score.compareTo(a.score));
    final best = candidates.first;
    if (best.score < .50) return null;
    return MetadataDraft(
      title: best.trackTitle ?? safeTitle,
      artist: best.artist.isEmpty ? safeArtist : best.artist,
      album: best.album,
      genre:
          best.genre ??
          fallback?.genre ??
          _genreGuess('${best.album} $safeTitle'),
      confidence: best.score.clamp(.50, .94),
      coverUrl: best.coverUrl ?? fallback?.coverUrl,
      sourceLabel: '${best.sourceLabel} album match',
      releaseId: best.releaseId ?? fallback?.releaseId,
      artistImageUrl:
          best.artistImageUrl ??
          fallback?.artistImageUrl ??
          await _artistImageFor(best.artist.isEmpty ? safeArtist : best.artist),
    );
  }

  List<MetadataDraft> _dedupeDrafts(List<MetadataDraft> drafts) {
    final seen = <String>{};
    final result = <MetadataDraft>[];
    for (final draft in drafts) {
      final key =
          '${draft.title.toLowerCase().trim()}|${draft.artist.toLowerCase().trim()}|${draft.album.toLowerCase().trim()}';
      if (seen.add(key)) result.add(draft);
    }
    return result;
  }

  List<MetadataDraft> _rankAndLimitDrafts(
    List<MetadataDraft> drafts, {
    required int limit,
  }) {
    final ranked = _dedupeDrafts(drafts)
      ..sort((a, b) => _metadataRank(b).compareTo(_metadataRank(a)));
    return ranked.take(limit).toList();
  }

  double _metadataRank(MetadataDraft draft) {
    var score = draft.confidence;
    if (_hasAlbumContext(draft.album)) score += .08;
    if (!_hasAlbumContext(draft.album)) score -= .08;
    if (draft.coverUrl != null) score += .03;
    if (draft.sourceLabel.contains('MusicBrainz')) score += .02;
    if (draft.sourceLabel.contains('YouTube')) score -= .04;
    return score;
  }

  Future<MetadataDraft> _draftFromBestSearchProvider(String query) async {
    final options = await draftOptionsFromInput(
      songQuery: query,
      youtubeUrl: '',
      limit: 5,
    );
    if (options.isNotEmpty) return options.first;
    final musicBrainz = await _draftFromMusicBrainz(query);
    final youtube = await _draftFromYoutubeSearch(query);
    if (youtube != null) return youtube;
    return musicBrainz;
  }

  Future<MetadataDraft?> _draftFromAudioFingerprint(
    String path, {
    required _EmbeddedAudioMetadata embedded,
  }) async {
    final fingerprint = await _fingerprintAudio(path);
    if (fingerprint == null) return null;
    final clientKey = Platform.environment['ACOUSTID_API_KEY']?.trim();
    final client = clientKey?.isNotEmpty == true
        ? clientKey!
        : _acoustIdDemoClient;
    try {
      final data =
          await _postFormJson(Uri.https('api.acoustid.org', '/v2/lookup'), {
            'client': client,
            'format': 'json',
            'duration': fingerprint.durationSeconds.toString(),
            'fingerprint': fingerprint.fingerprint,
            'meta': 'recordings+recordingids+releases+releasegroups+compress',
          });
      if (data['status'] != 'ok') return null;
      final results = data['results'];
      if (results is! List || results.isEmpty) return null;
      final sorted = results.whereType<Map<String, dynamic>>().toList()
        ..sort(
          (a, b) => (((b['score'] as num?)?.toDouble() ?? 0).compareTo(
            (a['score'] as num?)?.toDouble() ?? 0,
          )),
        );
      for (final result in sorted.take(4)) {
        final score = (result['score'] as num?)?.toDouble() ?? 0;
        if (score < .70) continue;
        final recordings = result['recordings'];
        if (recordings is! List || recordings.isEmpty) continue;
        for (final recording
            in recordings.whereType<Map<String, dynamic>>().take(4)) {
          final recordingId = recording['id'] as String?;
          final draft = recordingId == null
              ? await _draftFromAcoustIdRecording(
                  recording,
                  score,
                  embedded: embedded,
                )
              : await _draftFromMusicBrainzRecording(
                  recordingId,
                  acoustIdScore: score,
                  embedded: embedded,
                );
          if (draft != null) return draft;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<_AudioFingerprint?> _fingerprintAudio(String path) async {
    try {
      final result = await Process.run('fpcalc', [
        '-json',
        path,
      ]).timeout(const Duration(seconds: 12));
      if (result.exitCode == 0) {
        final data =
            jsonDecode(result.stdout as String) as Map<String, dynamic>;
        final duration = (data['duration'] as num?)?.round();
        final fingerprint = data['fingerprint'] as String?;
        if (duration != null &&
            duration > 0 &&
            fingerprint != null &&
            fingerprint.isNotEmpty) {
          return _AudioFingerprint(
            durationSeconds: duration,
            fingerprint: fingerprint,
          );
        }
      }
    } catch (_) {
      // Try classic key=value output below.
    }
    try {
      final result = await Process.run('fpcalc', [
        path,
      ]).timeout(const Duration(seconds: 12));
      if (result.exitCode != 0) return null;
      int? duration;
      String? fingerprint;
      for (final line in (result.stdout as String).split('\n')) {
        if (line.startsWith('DURATION=')) {
          duration = double.tryParse(line.substring(9))?.round();
        }
        if (line.startsWith('FINGERPRINT=')) {
          fingerprint = line.substring(12).trim();
        }
      }
      if (duration != null &&
          duration > 0 &&
          fingerprint != null &&
          fingerprint.isNotEmpty) {
        return _AudioFingerprint(
          durationSeconds: duration,
          fingerprint: fingerprint,
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<List<MetadataDraft>> _draftsFromAppleMusicSearch(
    String query, {
    required int limit,
  }) async {
    final safeQuery = query.trim();
    if (safeQuery.isEmpty) {
      return const [];
    }
    final drafts = <MetadataDraft>[];
    try {
      final uri = Uri.https('itunes.apple.com', '/search', {
        'term': safeQuery,
        'media': 'music',
        'entity': 'song',
        'limit': '8',
      });
      final data = await _getJson(uri);
      final results = data['results'];
      if (results is List && results.isNotEmpty) {
        for (final result in results.take(8)) {
          final item = result as Map<String, dynamic>;
          final title = item['trackName'] as String? ?? '';
          final artist = item['artistName'] as String? ?? '';
          final album = item['collectionName'] as String? ?? 'Single';
          final trackCount = (item['trackCount'] as num?)?.toInt();
          var confidence = _textMetadataConfidence(
            safeQuery,
            title,
            artist,
            providerScore: .86,
          );
          if (_hasAlbumContext(album) &&
              (trackCount == null || trackCount > 1)) {
            confidence += .04;
          }
          if (!_hasAlbumContext(album) || trackCount == 1) confidence -= .05;
          if (confidence < .52) {
            continue;
          }
          final artwork = item['artworkUrl100'] as String?;
          drafts.add(
            MetadataDraft(
              title: title.isEmpty ? safeQuery : title,
              artist: artist.isEmpty ? 'Unknown Artist' : artist,
              album: album,
              genre:
                  item['primaryGenreName'] as String? ?? _genreGuess(safeQuery),
              confidence: confidence.clamp(.45, .90),
              coverUrl: await _cacheRemoteImage(
                artwork?.replaceAll('100x100bb', '600x600bb'),
                'cover-$title-$artist',
              ),
              sourceLabel: 'Apple Music Search',
              artistImageUrl: await _artistImageFor(artist),
            ),
          );
        }
      }
    } catch (_) {
      // Fall through to MusicBrainz.
    }
    return _rankAndLimitDrafts(drafts, limit: limit);
  }

  Future<List<MetadataDraft>> _draftsFromDeezerSearch(
    String query, {
    required int limit,
  }) async {
    final safeQuery = query.trim();
    if (safeQuery.isEmpty) return const [];
    final drafts = <MetadataDraft>[];
    try {
      final uri = Uri.https('api.deezer.com', '/search', {
        'q': safeQuery,
        'limit': '8',
      });
      final response = await _getJson(uri);
      final results = response['data'];
      if (results is List) {
        for (final result in results.whereType<Map<String, dynamic>>()) {
          final title =
              result['title_short'] as String? ??
              result['title'] as String? ??
              '';
          final artistData = result['artist'] as Map?;
          final albumData = result['album'] as Map?;
          final artist = artistData?['name'] as String? ?? '';
          final album = albumData?['title'] as String? ?? 'Single';
          var confidence = _textMetadataConfidence(
            safeQuery,
            title,
            artist,
            providerScore: .82,
          );
          if (_hasAlbumContext(album)) confidence += .04;
          if (confidence < .52) continue;
          drafts.add(
            MetadataDraft(
              title: title.isEmpty ? safeQuery : title,
              artist: artist.isEmpty ? 'Unknown Artist' : artist,
              album: album,
              genre: _genreGuess('$safeQuery $album'),
              confidence: confidence.clamp(.45, .88),
              coverUrl: await _cacheRemoteImage(
                albumData?['cover_xl'] as String? ??
                    albumData?['cover_big'] as String? ??
                    albumData?['cover_medium'] as String?,
                'cover-deezer-$title-$artist-$album',
              ),
              sourceLabel: 'Deezer Search',
              artistImageUrl: await _cacheRemoteImage(
                artistData?['picture_xl'] as String? ??
                    artistData?['picture_big'] as String?,
                'artist-deezer-$artist',
              ),
            ),
          );
        }
      }
    } catch (_) {
      // Deezer is an optional provider; ranking continues with the others.
    }
    return _rankAndLimitDrafts(drafts, limit: limit);
  }

  Future<List<_AlbumMetadataMatch>> _albumMatchesFromAppleMusic(
    String query, {
    required String targetTitle,
    required String targetArtist,
    required String targetAlbum,
  }) async {
    final matches = <_AlbumMetadataMatch>[];
    try {
      final search = await _getJson(
        Uri.https('itunes.apple.com', '/search', {
          'term': query,
          'media': 'music',
          'entity': 'album',
          'limit': '5',
        }),
      );
      final results = search['results'];
      if (results is! List) return matches;
      for (final item in results.whereType<Map<String, dynamic>>()) {
        final collectionId = item['collectionId'];
        final albumTitle = item['collectionName'] as String? ?? '';
        final albumArtist = item['artistName'] as String? ?? '';
        if (collectionId == null || albumTitle.isEmpty) continue;
        final albumScore = _albumContextScore(
          targetAlbum: targetAlbum,
          targetArtist: targetArtist,
          album: albumTitle,
          artist: albumArtist,
        );
        if (albumScore < .34) continue;
        final lookup = await _getJson(
          Uri.https('itunes.apple.com', '/lookup', {
            'id': collectionId.toString(),
            'entity': 'song',
            'limit': '200',
          }),
        );
        final lookupResults = lookup['results'];
        final songs = lookupResults is List
            ? lookupResults
                  .whereType<Map<String, dynamic>>()
                  .where((entry) => entry['wrapperType'] == 'track')
                  .toList()
            : const <Map<String, dynamic>>[];
        final bestTrack = _bestTrackMap(
          songs,
          targetTitle: targetTitle,
          titleKey: 'trackName',
        );
        final trackTitle = bestTrack?['trackName'] as String?;
        final trackScore = trackTitle == null
            ? .58
            : _titleMatchScore(targetTitle, trackTitle);
        final artwork = item['artworkUrl100'] as String?;
        matches.add(
          _AlbumMetadataMatch(
            album: albumTitle,
            artist: albumArtist,
            trackTitle: trackScore >= .45 ? trackTitle : targetTitle,
            genre:
                bestTrack?['primaryGenreName'] as String? ??
                item['primaryGenreName'] as String?,
            coverUrl: await _cacheRemoteImage(
              artwork?.replaceAll('100x100bb', '600x600bb'),
              'cover-album-apple-$albumTitle-$albumArtist',
            ),
            artistImageUrl: await _artistImageFor(albumArtist),
            releaseId: collectionId.toString(),
            sourceLabel: 'Apple Music',
            score: ((albumScore * .62) + (trackScore * .38)).clamp(0.0, .94),
          ),
        );
      }
    } catch (_) {
      // Optional album lookup source.
    }
    return matches;
  }

  Future<List<_AlbumMetadataMatch>> _albumMatchesFromDeezer(
    String query, {
    required String targetTitle,
    required String targetArtist,
    required String targetAlbum,
  }) async {
    final matches = <_AlbumMetadataMatch>[];
    try {
      final search = await _getJson(
        Uri.https('api.deezer.com', '/search/album', {
          'q': query,
          'limit': '5',
        }),
      );
      final results = search['data'];
      if (results is! List) return matches;
      for (final item in results.whereType<Map<String, dynamic>>()) {
        final albumId = item['id'];
        final albumTitle = item['title'] as String? ?? '';
        final artistData = item['artist'] as Map?;
        final albumArtist = artistData?['name'] as String? ?? '';
        if (albumId == null || albumTitle.isEmpty) continue;
        final albumScore = _albumContextScore(
          targetAlbum: targetAlbum,
          targetArtist: targetArtist,
          album: albumTitle,
          artist: albumArtist,
        );
        if (albumScore < .34) continue;
        final albumData = await _getJson(
          Uri.https('api.deezer.com', '/album/$albumId'),
        );
        final tracksData = (albumData['tracks'] as Map?)?['data'];
        final songs = tracksData is List
            ? tracksData.whereType<Map<String, dynamic>>().toList()
            : const <Map<String, dynamic>>[];
        final bestTrack = _bestTrackMap(
          songs,
          targetTitle: targetTitle,
          titleKey: 'title_short',
        );
        final trackTitle =
            bestTrack?['title_short'] as String? ??
            bestTrack?['title'] as String?;
        final trackScore = trackTitle == null
            ? .58
            : _titleMatchScore(targetTitle, trackTitle);
        final genresData = (albumData['genres'] as Map?)?['data'];
        final firstGenre = genresData is List && genresData.isNotEmpty
            ? ((genresData.first as Map?)?['name'] as String?)
            : null;
        matches.add(
          _AlbumMetadataMatch(
            album: albumTitle,
            artist: albumArtist,
            trackTitle: trackScore >= .45 ? trackTitle : targetTitle,
            genre: firstGenre,
            coverUrl: await _cacheRemoteImage(
              albumData['cover_xl'] as String? ??
                  albumData['cover_big'] as String? ??
                  item['cover_xl'] as String?,
              'cover-album-deezer-$albumTitle-$albumArtist',
            ),
            artistImageUrl: await _cacheRemoteImage(
              artistData?['picture_xl'] as String? ??
                  artistData?['picture_big'] as String?,
              'artist-deezer-$albumArtist',
            ),
            releaseId: albumId.toString(),
            sourceLabel: 'Deezer',
            score: ((albumScore * .62) + (trackScore * .38)).clamp(0.0, .92),
          ),
        );
      }
    } catch (_) {
      // Optional album lookup source.
    }
    return matches;
  }

  Future<List<_AlbumMetadataMatch>> _albumMatchesFromMusicBrainz(
    String query, {
    required String targetTitle,
    required String targetArtist,
    required String targetAlbum,
  }) async {
    final matches = <_AlbumMetadataMatch>[];
    try {
      final data = await _getMusicBrainzJson(
        Uri.https('musicbrainz.org', '/ws/2/release-group', {
          'query': query,
          'fmt': 'json',
          'limit': '5',
        }),
      );
      final groups = data['release-groups'];
      if (groups is! List) return matches;
      for (final group in groups.whereType<Map<String, dynamic>>()) {
        final groupId = group['id'] as String?;
        final albumTitle = group['title'] as String? ?? '';
        final artist =
            _artistFromCredits(group['artist-credit']) ?? targetArtist;
        if (groupId == null || albumTitle.isEmpty) continue;
        final albumScore = _albumContextScore(
          targetAlbum: targetAlbum,
          targetArtist: targetArtist,
          album: albumTitle,
          artist: artist,
        );
        if (albumScore < .34) continue;
        matches.add(
          _AlbumMetadataMatch(
            album: albumTitle,
            artist: artist,
            trackTitle: targetTitle,
            genre: _genreGuess('$albumTitle $targetTitle'),
            coverUrl: await _coverForMusicBrainzIds(
              releaseGroupId: groupId,
              key: 'album-$albumTitle-$artist',
            ),
            artistImageUrl: await _artistImageForMusicBrainz(
              artist,
              group['artist-credit'],
            ),
            releaseId: groupId,
            sourceLabel: 'MusicBrainz',
            score: (albumScore * .88).clamp(0.0, .88),
          ),
        );
      }
    } catch (_) {
      // Optional album lookup source.
    }
    return matches;
  }

  Future<AlbumDraft> albumDraftFromYoutubePlaylist(String playlistUrl) async {
    final uri = Uri.tryParse(playlistUrl.trim());
    final listId = uri?.queryParameters['list'] ?? 'playlist';
    final fallbackTitle = 'YouTube playlist $listId';
    try {
      final result = await Process.run('yt-dlp', [
        '--flat-playlist',
        '--dump-single-json',
        '--no-warnings',
        playlistUrl.trim(),
      ]).timeout(const Duration(seconds: 24));
      if (result.exitCode != 0) {
        return _fallbackPlaylistDraft(playlistUrl, fallbackTitle);
      }
      final data = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final title = (data['title'] as String?)?.trim();
      final artist = _cleanArtistName(
        (data['artist'] as String?) ??
            (data['uploader'] as String?) ??
            (data['channel'] as String?) ??
            'Unknown Artist',
      );
      final entries = data['entries'];
      final tracks = <AlbumTrackDraft>[];
      if (entries is List) {
        for (final entry in entries.whereType<Map<String, dynamic>>()) {
          final rawTitle = (entry['title'] as String?)?.trim();
          if (rawTitle == null ||
              rawTitle.isEmpty ||
              rawTitle == '[Deleted video]' ||
              rawTitle == '[Private video]') {
            continue;
          }
          final parsed = _splitArtistAndTitle(_cleanYoutubeTitle(rawTitle));
          final entryArtist = parsed.$1 == 'Unknown Artist'
              ? _cleanArtistName(
                  (entry['artist'] as String?) ??
                      (entry['uploader'] as String?) ??
                      (entry['channel'] as String?) ??
                      artist,
                )
              : _cleanArtistName(parsed.$1);
          final durationSeconds = (entry['duration'] as num?)?.round();
          tracks.add(
            AlbumTrackDraft(
              index: tracks.length + 1,
              title: parsed.$2.isEmpty ? rawTitle : parsed.$2,
              artist: entryArtist.isEmpty ? artist : entryArtist,
              duration: durationSeconds == null || durationSeconds <= 0
                  ? null
                  : Duration(seconds: durationSeconds),
            ),
          );
        }
      }
      if (tracks.isEmpty) {
        return _fallbackPlaylistDraft(playlistUrl, fallbackTitle);
      }
      return AlbumDraft(
        id: 'album-${DateTime.now().microsecondsSinceEpoch}',
        sourceUrl: playlistUrl.trim(),
        title: title?.isNotEmpty == true ? title! : fallbackTitle,
        artist: artist.isEmpty ? 'Unknown Artist' : artist,
        coverUrl: await _cacheRemoteImage(
          _bestThumbnail(data),
          'cover-playlist-$listId-${title ?? fallbackTitle}',
        ),
        tracks: tracks,
      );
    } catch (_) {
      return _fallbackPlaylistDraft(playlistUrl, fallbackTitle);
    }
  }

  AlbumDraft _fallbackPlaylistDraft(String playlistUrl, String title) {
    return AlbumDraft(
      id: 'album-${DateTime.now().microsecondsSinceEpoch}',
      sourceUrl: playlistUrl.trim(),
      title: title,
      artist: 'Unknown Artist',
      coverUrl: null,
      tracks: const [],
    );
  }

  Future<MetadataDraft> _draftFromMusicBrainz(String query) async {
    final drafts = await _draftsFromMusicBrainz(query, limit: 1);
    if (drafts.isNotEmpty) return drafts.first;
    final safeQuery = query.trim().isEmpty ? 'Untitled Track' : query.trim();
    final guessed = _splitArtistAndTitle(safeQuery);
    return MetadataDraft(
      title: guessed.$2,
      artist: guessed.$1,
      album: 'Single',
      genre: _genreGuess(safeQuery),
      confidence: .42,
      coverUrl: null,
      sourceLabel: 'Filename fallback',
      artistImageUrl: await _artistImageFor(guessed.$1),
    );
  }

  Future<List<MetadataDraft>> _draftsFromMusicBrainz(
    String query, {
    required int limit,
  }) async {
    final safeQuery = query.trim().isEmpty ? 'Untitled Track' : query.trim();
    final drafts = <MetadataDraft>[];
    try {
      final uri = Uri.https('musicbrainz.org', '/ws/2/recording', {
        'query': safeQuery,
        'fmt': 'json',
        'limit': '8',
      });
      final data = await _getMusicBrainzJson(uri);
      final recordings = data['recordings'];
      if (recordings is List && recordings.isNotEmpty) {
        for (final recording in recordings.whereType<Map<String, dynamic>>()) {
          final artistCredit = recording['artist-credit'];
          final artist = artistCredit is List && artistCredit.isNotEmpty
              ? (artistCredit.first as Map<String, dynamic>)['name']
                        as String? ??
                    'Unknown Artist'
              : 'Unknown Artist';
          final title = recording['title'] as String? ?? safeQuery;
          final providerScore =
              ((recording['score'] as num?)?.toDouble() ?? 65) / 100;
          final confidence = _textMetadataConfidence(
            safeQuery,
            title,
            artist,
            providerScore: providerScore,
          );
          if (confidence < .55) continue;
          final releases = recording['releases'];
          final release = releases is List && releases.isNotEmpty
              ? releases.first as Map<String, dynamic>
              : null;
          final releaseId = release?['id'] as String?;
          drafts.add(
            MetadataDraft(
              title: title,
              artist: artist,
              album: release?['title'] as String? ?? 'Single',
              genre: _genreGuess(safeQuery),
              confidence: confidence,
              coverUrl: await _cacheRemoteImage(
                releaseId == null
                    ? null
                    : 'https://coverartarchive.org/release/$releaseId/front-500',
                'cover-$safeQuery-$releaseId',
              ),
              sourceLabel: 'MusicBrainz',
              releaseId: releaseId,
              artistImageUrl: await _artistImageFor(artist),
            ),
          );
          if (drafts.length >= limit) break;
        }
      }
    } catch (_) {
      // Offline or rate-limited: fall back to filename-derived metadata.
    }
    return drafts;
  }

  Future<MetadataDraft?> _draftFromMusicBrainzRecording(
    String recordingId, {
    required double acoustIdScore,
    required _EmbeddedAudioMetadata embedded,
  }) async {
    try {
      final uri = Uri.https('musicbrainz.org', '/ws/2/recording/$recordingId', {
        'fmt': 'json',
        'inc': 'artist-credits+releases+release-groups+genres+tags',
      });
      final recording = await _getMusicBrainzJson(uri);
      return _draftFromMusicBrainzRecordingMap(
        recording,
        acoustIdScore: acoustIdScore,
        embedded: embedded,
        sourceLabel: 'AcoustID + MusicBrainz',
      );
    } catch (_) {
      return null;
    }
  }

  Future<MetadataDraft?> _draftFromAcoustIdRecording(
    Map<String, dynamic> recording,
    double score, {
    required _EmbeddedAudioMetadata embedded,
  }) {
    return _draftFromMusicBrainzRecordingMap(
      recording,
      acoustIdScore: score,
      embedded: embedded,
      sourceLabel: 'AcoustID',
    );
  }

  Future<MetadataDraft?> _draftFromMusicBrainzRecordingMap(
    Map<String, dynamic> recording, {
    required double acoustIdScore,
    required _EmbeddedAudioMetadata embedded,
    required String sourceLabel,
  }) async {
    final title = (recording['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return null;
    final artist =
        _artistFromCredits(
          recording['artist-credit'] ?? recording['artists'],
        ) ??
        embedded.artist ??
        'Unknown Artist';
    final release = _bestRelease(recording['releases']);
    final releaseId = release?['id'] as String?;
    final releaseGroup = release?['release-group'] as Map<String, dynamic>?;
    final releaseGroupId =
        releaseGroup?['id'] as String? ??
        _firstReleaseGroupId(recording['releasegroups']);
    final album =
        (release?['title'] as String?) ??
        (releaseGroup?['title'] as String?) ??
        embedded.album ??
        'Single';
    final genre =
        _genreFromMetadata(recording) ??
        embedded.genre ??
        _genreGuess('$title $artist');
    final cover = await _coverForMusicBrainzIds(
      releaseId: releaseId,
      releaseGroupId: releaseGroupId,
      key: '$title-$artist',
    );
    return MetadataDraft(
      title: title,
      artist: artist,
      album: album,
      genre: genre,
      confidence: acoustIdScore.clamp(0.0, .98),
      coverUrl: cover,
      sourceLabel: sourceLabel,
      releaseId: releaseId ?? releaseGroupId,
      artistImageUrl: await _artistImageForMusicBrainz(
        artist,
        recording['artist-credit'] ?? recording['artists'],
      ),
    );
  }

  String? _artistFromCredits(dynamic credits) {
    if (credits is! List || credits.isEmpty) return null;
    final names = <String>[];
    for (final item in credits.whereType<Map<String, dynamic>>()) {
      final name =
          item['name'] as String? ??
          (item['artist'] as Map?)?['name'] as String?;
      if (name != null && name.trim().isNotEmpty) names.add(name.trim());
    }
    if (names.isEmpty) return null;
    return names.join(', ');
  }

  Map<String, dynamic>? _bestRelease(dynamic releases) {
    if (releases is! List || releases.isEmpty) return null;
    final typed = releases.whereType<Map<String, dynamic>>().toList();
    if (typed.isEmpty) return null;
    typed.sort((a, b) {
      final aScore = _releaseAlbumPreferenceScore(a);
      final bScore = _releaseAlbumPreferenceScore(b);
      if (aScore != bScore) return bScore.compareTo(aScore);
      final aDate = a['date'] as String? ?? '9999';
      final bDate = b['date'] as String? ?? '9999';
      return aDate.compareTo(bDate);
    });
    return typed.first;
  }

  int _releaseAlbumPreferenceScore(Map<String, dynamic> release) {
    var score = 0;
    if ((release['status'] as String?) == 'Official') score += 20;
    final releaseGroup = release['release-group'] as Map<String, dynamic>?;
    final primaryType =
        (releaseGroup?['primary-type'] as String? ??
                release['primary-type'] as String? ??
                '')
            .toLowerCase();
    final secondaryTypes = releaseGroup?['secondary-types'];
    final title = release['title'] as String? ?? '';
    if (primaryType == 'album') score += 45;
    if (primaryType == 'ep') score += 28;
    if (primaryType == 'single') score -= 20;
    if (secondaryTypes is List &&
        secondaryTypes.any(
          (type) => type.toString().toLowerCase() == 'compilation',
        )) {
      score -= 14;
    }
    if (_hasAlbumContext(title)) score += 8;
    return score;
  }

  String? _firstReleaseGroupId(dynamic releaseGroups) {
    if (releaseGroups is List && releaseGroups.isNotEmpty) {
      return (releaseGroups.first as Map?)?['id'] as String?;
    }
    return null;
  }

  String? _genreFromMetadata(Map<String, dynamic> data) {
    final genres = data['genres'];
    if (genres is List && genres.isNotEmpty) {
      return (genres.first as Map?)?['name'] as String?;
    }
    final tags = data['tags'];
    if (tags is List && tags.isNotEmpty) {
      final sorted = tags.whereType<Map<String, dynamic>>().toList()
        ..sort(
          (a, b) => (((b['count'] as num?)?.toInt() ?? 0).compareTo(
            (a['count'] as num?)?.toInt() ?? 0,
          )),
        );
      return sorted.isEmpty ? null : sorted.first['name'] as String?;
    }
    return null;
  }

  Future<String?> _coverForMusicBrainzIds({
    String? releaseId,
    String? releaseGroupId,
    required String key,
  }) async {
    final releaseCover = await _cacheRemoteImage(
      releaseId == null
          ? null
          : 'https://coverartarchive.org/release/$releaseId/front-500',
      'cover-release-$key-$releaseId',
    );
    if (releaseCover != null) return releaseCover;
    return _cacheRemoteImage(
      releaseGroupId == null
          ? null
          : 'https://coverartarchive.org/release-group/$releaseGroupId/front-500',
      'cover-release-group-$key-$releaseGroupId',
    );
  }

  Future<MetadataDraft> _draftFromYoutubeLink(
    String url, {
    required String fallbackQuery,
  }) async {
    final ytdlp = await _draftFromYtDlp(url, sourceLabel: 'yt-dlp YouTube');
    if (ytdlp != null) return ytdlp;
    final guessed = _splitArtistAndTitle(
      fallbackQuery.trim().isEmpty
          ? 'Unknown Artist - YouTube track'
          : fallbackQuery,
    );
    try {
      final uri = Uri.https('www.youtube.com', '/oembed', {
        'url': url,
        'format': 'json',
      });
      final data = await _getJson(uri);
      final title = data['title'] as String? ?? guessed.$2;
      final parsed = _splitArtistAndTitle(_cleanYoutubeTitle(title));
      return MetadataDraft(
        title: parsed.$2,
        artist: parsed.$1 == 'Unknown Artist' ? guessed.$1 : parsed.$1,
        album: 'Single',
        genre: _genreGuess(title),
        confidence: .70,
        coverUrl: await _cacheRemoteImage(
          data['thumbnail_url'] as String?,
          'cover-${parsed.$2}-${parsed.$1}',
        ),
        sourceLabel: 'YouTube oEmbed',
        artistImageUrl: await _artistImageFor(
          parsed.$1 == 'Unknown Artist' ? guessed.$1 : parsed.$1,
        ),
      );
    } catch (_) {
      return MetadataDraft(
        title: guessed.$2,
        artist: guessed.$1,
        album: 'Single',
        genre: _genreGuess(fallbackQuery),
        confidence: .50,
        coverUrl: null,
        sourceLabel: 'YouTube fallback',
        artistImageUrl: await _artistImageFor(guessed.$1),
      );
    }
  }

  Future<MetadataDraft?> _draftFromYoutubeSearch(String query) {
    final safeQuery = query.trim();
    if (safeQuery.isEmpty) return Future.value(null);
    return _draftFromYtDlpFlatSearch(safeQuery);
  }

  Future<MetadataDraft?> _draftFromYtDlpFlatSearch(String query) async {
    try {
      final result = await Process.run('yt-dlp', [
        '--flat-playlist',
        '--dump-json',
        'ytsearch1:$query',
      ]).timeout(const Duration(seconds: 14));
      if (result.exitCode != 0) return null;
      final lines = (result.stdout as String)
          .split('\n')
          .where((line) => line.trim().isNotEmpty);
      if (lines.isEmpty) return null;
      final data = jsonDecode(lines.first) as Map<String, dynamic>;
      final rawTitle = data['title'] as String? ?? query;
      final title = _cleanYoutubeTitle(rawTitle);
      final parsed = _splitArtistAndTitle(title);
      final artist = _cleanArtistName(parsed.$1);
      final confidence = _textMetadataConfidence(
        query,
        parsed.$2,
        artist,
        providerScore: .78,
      );
      if (confidence < .52) return null;
      return MetadataDraft(
        title: parsed.$1 == 'Unknown Artist' ? title : parsed.$2,
        artist: artist.isEmpty ? 'Unknown Artist' : artist,
        album: 'Single',
        genre: _genreGuess(title),
        confidence: confidence.clamp(.45, .80),
        coverUrl: await _cacheRemoteImage(
          _bestThumbnail(data),
          'cover-$title-$artist',
        ),
        sourceLabel: 'yt-dlp Search',
        artistImageUrl: await _artistImageFor(artist),
      );
    } catch (_) {
      return null;
    }
  }

  Future<MetadataDraft?> _draftFromYtDlp(
    String target, {
    required String sourceLabel,
  }) async {
    try {
      final result = await Process.run('yt-dlp', [
        '--dump-single-json',
        '--no-playlist',
        '--skip-download',
        target,
      ]).timeout(const Duration(seconds: 14));
      if (result.exitCode != 0) return null;
      final data = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final rawTitle =
          data['track'] as String? ?? data['title'] as String? ?? '';
      final rawArtist =
          data['artist'] as String? ?? data['uploader'] as String? ?? '';
      final title = _cleanYoutubeTitle(rawTitle);
      final parsed = _splitArtistAndTitle(title);
      final artist =
          rawArtist.isNotEmpty && !rawArtist.toLowerCase().contains('topic')
          ? rawArtist
          : parsed.$1;
      final cleanArtist = _cleanArtistName(artist);
      return MetadataDraft(
        title: parsed.$1 == 'Unknown Artist' ? title : parsed.$2,
        artist: cleanArtist.isEmpty ? 'Unknown Artist' : cleanArtist,
        album: data['album'] as String? ?? 'Single',
        genre: data['genre'] as String? ?? _genreGuess(title),
        confidence: sourceLabel.contains('Search') ? .76 : .86,
        coverUrl: await _cacheRemoteImage(
          _bestThumbnail(data),
          'cover-$title-$cleanArtist',
        ),
        sourceLabel: sourceLabel,
        artistImageUrl: await _artistImageFor(
          cleanArtist.isEmpty ? parsed.$1 : cleanArtist,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<_EmbeddedAudioMetadata> _readEmbeddedMetadata(String path) async {
    try {
      final result = await Process.run('ffprobe', [
        '-v',
        'quiet',
        '-print_format',
        'json',
        '-show_format',
        path,
      ]).timeout(const Duration(seconds: 6));
      if (result.exitCode != 0) return const _EmbeddedAudioMetadata();
      final data = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final format = data['format'] as Map<String, dynamic>?;
      final tags =
          (format?['tags'] as Map?)?.map(
            (key, value) =>
                MapEntry(key.toString().toLowerCase(), value.toString()),
          ) ??
          const <String, String>{};
      return _EmbeddedAudioMetadata(
        title: tags['title'],
        artist: tags['artist'] ?? tags['album_artist'],
        album: tags['album'],
        genre: tags['genre'],
      );
    } catch (_) {
      return const _EmbeddedAudioMetadata();
    }
  }

  Future<String?> _extractEmbeddedCover(String audioPath) async {
    try {
      final cache = await _imageCacheDir();
      final outPath = '${cache.path}/embedded-${_safeFileName(audioPath)}.jpg';
      final result = await Process.run('ffmpeg', [
        '-y',
        '-i',
        audioPath,
        '-an',
        '-vframes',
        '1',
        '-vf',
        'scale=${coverPolicy.maxDimension}:${coverPolicy.maxDimension}:force_original_aspect_ratio=decrease',
        outPath,
      ]).timeout(const Duration(seconds: 8));
      final file = File(outPath);
      if (result.exitCode == 0 &&
          await file.exists() &&
          await file.length() > 0) {
        return outPath;
      }
    } catch (_) {
      // No embedded cover, unsupported stream, or ffmpeg unavailable.
    }
    return null;
  }

  Future<String?> _cacheRemoteImage(String? url, String key) async {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('/') || url.startsWith('file://')) {
      return url.replaceFirst('file://', '');
    }
    try {
      final cache = await _imageCacheDir();
      final safeKey = _safeFileName(key);
      final outPath = '${cache.path}/$safeKey.jpg';
      final outFile = File(outPath);
      if (await outFile.exists() && await outFile.length() > 0) return outPath;
      final downloadPath = '${cache.path}/$safeKey.download';
      final downloadFile = File(downloadPath);
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.getUrl(Uri.parse(url));
        request.headers.set(
          HttpHeaders.userAgentHeader,
          'Mozilla/5.0 CanaryDesktop/0.1',
        );
        final response = await request.close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return null;
        }
        await response.pipe(downloadFile.openWrite());
      } finally {
        client.close(force: true);
      }
      if (!await downloadFile.exists() || await downloadFile.length() == 0) {
        return null;
      }
      final converted = await _convertImageToJpeg(downloadPath, outPath);
      if (converted) {
        try {
          await downloadFile.delete();
        } catch (_) {
          // Cache cleanup is best-effort.
        }
        return outPath;
      }
      return downloadPath;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _convertImageToJpeg(String inputPath, String outputPath) async {
    try {
      final result = await Process.run('ffmpeg', [
        '-y',
        '-i',
        inputPath,
        '-vf',
        'scale=${coverPolicy.maxDimension}:${coverPolicy.maxDimension}:force_original_aspect_ratio=decrease',
        '-q:v',
        '5',
        outputPath,
      ]).timeout(const Duration(seconds: 8));
      final outFile = File(outputPath);
      return result.exitCode == 0 &&
          await outFile.exists() &&
          await outFile.length() > 0;
    } catch (_) {
      return false;
    }
  }

  Future<Directory> _imageCacheDir() async {
    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    final dir = Directory('$home/.cache/canary/images');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _safeFileName(String value) {
    final safe = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+\$'), '');
    if (safe.isEmpty) return 'image-${DateTime.now().microsecondsSinceEpoch}';
    return safe.length <= 80 ? safe : safe.substring(0, 80);
  }

  Future<String?> _artistImageFor(String artist) async {
    final normalized = artist.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'unknown artist') return null;
    if (_artistImageCache.containsKey(normalized)) {
      return _artistImageCache[normalized];
    }
    try {
      final result = await Process.run('yt-dlp', [
        '--flat-playlist',
        '--dump-json',
        'ytsearch1:$artist official artist channel',
      ]).timeout(const Duration(seconds: 10));
      if (result.exitCode == 0) {
        final lines = (result.stdout as String)
            .split('\n')
            .where((line) => line.trim().isNotEmpty);
        if (lines.isEmpty) {
          _artistImageCache[normalized] = null;
          return null;
        }
        final data = jsonDecode(lines.first) as Map<String, dynamic>;
        final channel =
            data['channel'] as String? ?? data['uploader'] as String? ?? '';
        final thumbnail =
            data['channel_thumbnail'] as String? ?? _bestThumbnail(data);
        final confidence = _tokenConfidence(artist, channel);
        _artistImageCache[normalized] = confidence >= .34
            ? await _cacheRemoteImage(thumbnail, 'artist-$artist')
            : null;
        return _artistImageCache[normalized];
      }
    } catch (_) {
      // Keep missing artist art cached so we do not repeatedly hit the network.
    }
    _artistImageCache[normalized] = null;
    return null;
  }

  String? _bestThumbnail(Map<String, dynamic> data) {
    final thumbnails = data['thumbnails'];
    if (thumbnails is List && thumbnails.isNotEmpty) {
      Map<String, dynamic>? best;
      for (final item in thumbnails.whereType<Map<String, dynamic>>()) {
        final url = item['url'] as String?;
        if (url == null || url.isEmpty) continue;
        final width = (item['width'] as num?)?.toInt() ?? 0;
        if (best == null || width > ((best['width'] as num?)?.toInt() ?? 0)) {
          best = item;
        }
      }
      final bestUrl = best?['url'] as String?;
      if (bestUrl != null && bestUrl.isNotEmpty) return bestUrl;
    }
    return data['thumbnail'] as String?;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'CanaryDesktop/0.1 (local music metadata app)',
      );
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const HttpException('metadata request failed');
      }
      final text = await response.transform(utf8.decoder).join();
      return jsonDecode(text) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _postFormJson(
    Uri uri,
    Map<String, String> fields,
  ) async {
    final body = fields.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.postUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'CanaryDesktop/0.1 (local music metadata app)',
      );
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/x-www-form-urlencoded',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.write(body);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const HttpException('metadata form request failed');
      }
      final text = await response.transform(utf8.decoder).join();
      return jsonDecode(text) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _getMusicBrainzJson(Uri uri) async {
    final elapsed = DateTime.now().difference(_lastMusicBrainzRequest);
    if (elapsed < const Duration(milliseconds: 1100)) {
      await Future<void>.delayed(const Duration(milliseconds: 1100) - elapsed);
    }
    _lastMusicBrainzRequest = DateTime.now();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'CanaryDesktop/0.1 (https://localhost; local music metadata app)',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const HttpException('musicbrainz request failed');
      }
      final text = await response.transform(utf8.decoder).join();
      return jsonDecode(text) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Future<String?> _artistImageForMusicBrainz(
    String artistName,
    dynamic artistCredits,
  ) async {
    final artistId = _artistIdFromCredits(artistCredits);
    if (artistId != null) {
      final image = await _artistImageFromMusicBrainzId(artistId, artistName);
      if (image != null) return image;
    }
    return _artistImageFor(artistName);
  }

  String? _artistIdFromCredits(dynamic credits) {
    if (credits is! List || credits.isEmpty) return null;
    final first = credits.first;
    if (first is Map<String, dynamic>) {
      return (first['artist'] as Map?)?['id'] as String? ??
          first['id'] as String?;
    }
    return null;
  }

  Future<String?> _artistImageFromMusicBrainzId(
    String artistId,
    String artistName,
  ) async {
    final normalized = artistName.trim().toLowerCase();
    final cacheKey = 'mbid:$artistId:$normalized';
    if (_artistImageCache.containsKey(cacheKey)) {
      return _artistImageCache[cacheKey];
    }
    try {
      final artist = await _getMusicBrainzJson(
        Uri.https('musicbrainz.org', '/ws/2/artist/$artistId', {
          'fmt': 'json',
          'inc': 'url-rels',
        }),
      );
      final wikidataId = _wikidataIdFromRelations(artist['relations']);
      if (wikidataId == null) {
        _artistImageCache[cacheKey] = null;
        return null;
      }
      final imageName = await _wikidataImageName(wikidataId);
      if (imageName == null) {
        _artistImageCache[cacheKey] = null;
        return null;
      }
      final imageUrl = Uri.https(
        'commons.wikimedia.org',
        '/wiki/Special:FilePath/$imageName',
        {'width': coverPolicy.maxDimension.toString()},
      ).toString();
      _artistImageCache[cacheKey] = await _cacheRemoteImage(
        imageUrl,
        'artist-$artistName-$artistId',
      );
      return _artistImageCache[cacheKey];
    } catch (_) {
      _artistImageCache[cacheKey] = null;
      return null;
    }
  }

  String? _wikidataIdFromRelations(dynamic relations) {
    if (relations is! List) return null;
    for (final relation in relations.whereType<Map<String, dynamic>>()) {
      final url = (relation['url'] as Map?)?['resource'] as String?;
      if (url == null) continue;
      final match = RegExp(
        r'wikidata\.org/(?:wiki|entity)/(Q\d+)',
      ).firstMatch(url);
      if (match != null) return match.group(1);
    }
    return null;
  }

  Future<String?> _wikidataImageName(String wikidataId) async {
    final data = await _getJson(
      Uri.https(
        'www.wikidata.org',
        '/wiki/Special:EntityData/$wikidataId.json',
      ),
    );
    final entities = data['entities'] as Map<String, dynamic>?;
    final entity = entities?[wikidataId] as Map<String, dynamic>?;
    final claims = entity?['claims'] as Map<String, dynamic>?;
    final p18 = claims?['P18'];
    if (p18 is List && p18.isNotEmpty) {
      return (((p18.first as Map?)?['mainsnak'] as Map?)?['datavalue']
              as Map?)?['value']
          as String?;
    }
    return null;
  }

  double _tokenConfidence(String query, String candidate) {
    final queryTokens = _tokens(query);
    if (queryTokens.isEmpty) return 0;
    final candidateTokens = _tokens(candidate).toSet();
    final hits = queryTokens.where(candidateTokens.contains).length;
    return hits / queryTokens.length;
  }

  double _albumContextScore({
    required String targetAlbum,
    required String targetArtist,
    required String album,
    required String artist,
  }) {
    final albumScore = _titleMatchScore(targetAlbum, album);
    final artistScore = targetArtist.trim().isEmpty
        ? .72
        : _titleMatchScore(targetArtist, artist);
    return ((albumScore * .76) + (artistScore * .24)).clamp(0.0, 1.0);
  }

  double _titleMatchScore(String expected, String candidate) {
    final expectedTokens = _matchTokens(expected);
    if (expectedTokens.isEmpty) return 0;
    final candidateTokens = _matchTokens(candidate).toSet();
    final hits = expectedTokens.where(candidateTokens.contains).length;
    return hits / expectedTokens.length;
  }

  Map<String, dynamic>? _bestTrackMap(
    List<Map<String, dynamic>> tracks, {
    required String targetTitle,
    required String titleKey,
  }) {
    Map<String, dynamic>? best;
    var bestScore = 0.0;
    for (final track in tracks) {
      final rawTitle =
          track[titleKey] as String? ?? track['title'] as String? ?? '';
      final score = _titleMatchScore(targetTitle, rawTitle);
      if (score > bestScore) {
        best = track;
        bestScore = score;
      }
    }
    return best;
  }

  double _textMetadataConfidence(
    String query,
    String title,
    String artist, {
    required double providerScore,
  }) {
    final parsed = _splitArtistAndTitle(query);
    final expectedTitleTokens = _matchTokens(parsed.$2);
    final expectedArtistTokens = _matchTokens(parsed.$1).toSet();
    final candidateTitleTokens = _matchTokens(title).toSet();
    final candidateArtistTokens = _matchTokens(artist).toSet();
    final titleScore = expectedTitleTokens.isEmpty
        ? _tokenConfidence(query, title)
        : expectedTitleTokens.where(candidateTitleTokens.contains).length /
              expectedTitleTokens.length;
    final artistScore = expectedArtistTokens.isEmpty
        ? 1.0
        : expectedArtistTokens.where(candidateArtistTokens.contains).length /
              expectedArtistTokens.length;
    final queryScore = _tokenConfidence(query, '$title $artist');
    var score =
        (titleScore * .58) +
        (artistScore * .22) +
        (queryScore * .10) +
        (providerScore * .10);
    if (expectedTitleTokens.isNotEmpty && titleScore == 0) {
      score = score.clamp(0.0, .42);
    }
    if (expectedTitleTokens.length >= 2 && titleScore < .50) {
      score = score.clamp(0.0, .50);
    }
    if (parsed.$1 != 'Unknown Artist' && expectedArtistTokens.isNotEmpty) {
      if (artistScore == 0) score = score.clamp(0.0, .46);
    }
    final candidateLower = '$title $artist'.toLowerCase();
    final queryLower = query.toLowerCase();
    const variantWords = [
      '8-bit',
      'emulation',
      'tribute',
      'karaoke',
      'instrumental',
      'remix',
      'cover',
    ];
    if (variantWords.any(
      (word) => candidateLower.contains(word) && !queryLower.contains(word),
    )) {
      score = score.clamp(0.0, .50);
    }
    return score;
  }

  List<String> _matchTokens(String value) {
    const ignored = {
      'feat',
      'ft',
      'with',
      'and',
      'official',
      'audio',
      'video',
      'visualizer',
      'lyrics',
      'lyric',
      'remastered',
    };
    return value
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.length >= 2 && !ignored.contains(token))
        .toList();
  }

  List<String> _tokens(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.length > 2)
        .toList();
  }

  String _cleanYoutubeTitle(String value) {
    return value
        .replaceAll(RegExp(r'\s*\[[^\]]*\]'), '')
        .replaceAll(
          RegExp(
            r'\s*\([^)]*(official|visualizer|audio|video|lyrics|lyric)[^)]*\)',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\s*official\s*(music)?\s*(video|audio|visualizer)?',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _cleanArtistName(String value) {
    return value
        .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  (String, String) _splitArtistAndTitle(String value) {
    final separators = [' - ', ' – ', ' — ', ' by '];
    for (final separator in separators) {
      if (value.contains(separator)) {
        final parts = value.split(separator);
        if (parts.length >= 2) {
          return (parts.first.trim(), parts.sublist(1).join(separator).trim());
        }
      }
    }
    return ('Unknown Artist', value.trim());
  }

  String _genreGuess(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('lofi') || lower.contains('chill')) return 'Lo-Fi';
    if (lower.contains('love') || lower.contains('heart')) return 'R&B';
    if (lower.contains('mix') || lower.contains('club')) return 'Electronic';
    if (lower.contains('rap') || lower.contains('drill')) return 'Hip-Hop';
    return 'Unsorted';
  }

  bool _hasAlbumContext(String album) {
    final normalized = album.trim().toLowerCase();
    return normalized.isNotEmpty &&
        normalized != 'single' &&
        normalized != 'unknown album';
  }
}

class _EmbeddedAudioMetadata {
  const _EmbeddedAudioMetadata({
    this.title,
    this.artist,
    this.album,
    this.genre,
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? genre;

  bool get hasUsefulTags =>
      (title?.isNotEmpty ?? false) || (artist?.isNotEmpty ?? false);

  MetadataDraft? toDraft({MetadataDraft? onlineDraft}) {
    if (!hasUsefulTags) return null;
    return MetadataDraft(
      title: title?.trim().isNotEmpty == true
          ? title!.trim()
          : onlineDraft?.title ?? 'Untitled Track',
      artist: artist?.trim().isNotEmpty == true
          ? artist!.trim()
          : onlineDraft?.artist ?? 'Unknown Artist',
      album: album?.trim().isNotEmpty == true
          ? album!.trim()
          : onlineDraft?.album ?? 'Single',
      genre: genre?.trim().isNotEmpty == true
          ? genre!.trim()
          : onlineDraft?.genre ?? 'Unsorted',
      confidence: .92,
      coverUrl: onlineDraft?.coverUrl,
      sourceLabel: onlineDraft?.coverUrl == null
          ? 'Embedded tags'
          : 'Embedded tags + online art',
      artistImageUrl: onlineDraft?.artistImageUrl,
    );
  }
}

class _AudioFingerprint {
  const _AudioFingerprint({
    required this.durationSeconds,
    required this.fingerprint,
  });

  final int durationSeconds;
  final String fingerprint;
}

class _AlbumMetadataMatch {
  const _AlbumMetadataMatch({
    required this.album,
    required this.artist,
    required this.sourceLabel,
    required this.score,
    this.trackTitle,
    this.genre,
    this.coverUrl,
    this.artistImageUrl,
    this.releaseId,
  });

  final String album;
  final String artist;
  final String sourceLabel;
  final double score;
  final String? trackTitle;
  final String? genre;
  final String? coverUrl;
  final String? artistImageUrl;
  final String? releaseId;
}
