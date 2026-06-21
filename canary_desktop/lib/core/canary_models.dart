enum CanarySourceKind { youtubeLink, manualSearch, localFile }

enum CoverCacheState { missing, queued, cached, failed }

class CoverAsset {
  const CoverAsset({
    required this.id,
    required this.sourceUrl,
    required this.localPath,
    required this.width,
    required this.height,
    required this.bytes,
    required this.state,
  });

  final String id;
  final String? sourceUrl;
  final String? localPath;
  final int width;
  final int height;
  final int bytes;
  final CoverCacheState state;

  CoverAsset copyWith({
    String? id,
    String? sourceUrl,
    String? localPath,
    int? width,
    int? height,
    int? bytes,
    CoverCacheState? state,
  }) {
    return CoverAsset(
      id: id ?? this.id,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      localPath: localPath ?? this.localPath,
      width: width ?? this.width,
      height: height ?? this.height,
      bytes: bytes ?? this.bytes,
      state: state ?? this.state,
    );
  }
}

class CanaryTrack {
  const CanaryTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    required this.duration,
    required this.sourceKind,
    required this.localPath,
    required this.cover,
    required this.addedAt,
    this.youtubeUrl,
    this.artistImageUrl,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final Duration duration;
  final CanarySourceKind sourceKind;
  final String? localPath;
  final String? youtubeUrl;
  final String? artistImageUrl;
  final CoverAsset cover;
  final DateTime addedAt;

  String get displayArtist => artist.isEmpty ? 'Unknown Artist' : artist;
  String get displayAlbum => album.isEmpty ? 'Single' : album;

  CanaryTrack copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? genre,
    Duration? duration,
    CanarySourceKind? sourceKind,
    String? localPath,
    String? youtubeUrl,
    String? artistImageUrl,
    CoverAsset? cover,
    DateTime? addedAt,
  }) {
    return CanaryTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      duration: duration ?? this.duration,
      sourceKind: sourceKind ?? this.sourceKind,
      localPath: localPath ?? this.localPath,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      artistImageUrl: artistImageUrl ?? this.artistImageUrl,
      cover: cover ?? this.cover,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}

class AutoPlaylist {
  const AutoPlaylist({
    required this.id,
    required this.name,
    required this.reason,
    required this.trackIds,
    required this.accent,
  });

  final String id;
  final String name;
  final String reason;
  final List<String> trackIds;
  final int accent;
}

class AlbumLook {
  const AlbumLook({
    required this.id,
    required this.sourceKey,
    required this.background,
    required this.primary,
    required this.secondary,
    required this.text,
  });

  final String id;
  final String? sourceKey;
  final int background;
  final int primary;
  final int secondary;
  final int text;
}

class MetadataDraft {
  const MetadataDraft({
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    required this.confidence,
    required this.coverUrl,
    required this.sourceLabel,
    this.releaseId,
    this.artistImageUrl,
  });

  final String title;
  final String artist;
  final String album;
  final String genre;
  final double confidence;
  final String? coverUrl;
  final String sourceLabel;
  final String? releaseId;
  final String? artistImageUrl;

  MetadataDraft copyWith({
    String? album,
    String? genre,
    String? coverUrl,
    String? artistImageUrl,
    String? sourceLabel,
  }) {
    return MetadataDraft(
      title: title,
      artist: artist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      confidence: confidence,
      coverUrl: coverUrl ?? this.coverUrl,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      releaseId: releaseId,
      artistImageUrl: artistImageUrl ?? this.artistImageUrl,
    );
  }
}

class ImportCandidate {
  const ImportCandidate({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.currentTitle,
    required this.currentArtist,
    required this.draft,
    required this.status,
  });

  final String id;
  final String filePath;
  final String fileName;
  final String currentTitle;
  final String currentArtist;
  final MetadataDraft? draft;
  final String status;

  ImportCandidate copyWith({MetadataDraft? draft, String? status}) {
    return ImportCandidate(
      id: id,
      filePath: filePath,
      fileName: fileName,
      currentTitle: currentTitle,
      currentArtist: currentArtist,
      draft: draft ?? this.draft,
      status: status ?? this.status,
    );
  }
}

class AlbumDraft {
  const AlbumDraft({
    required this.id,
    required this.sourceUrl,
    required this.title,
    required this.artist,
    required this.coverUrl,
    required this.tracks,
  });

  final String id;
  final String sourceUrl;
  final String title;
  final String artist;
  final String? coverUrl;
  final List<AlbumTrackDraft> tracks;
}

class AlbumTrackDraft {
  const AlbumTrackDraft({
    required this.index,
    required this.title,
    required this.artist,
    required this.duration,
    this.mappedFilePath,
  });

  final int index;
  final String title;
  final String artist;
  final Duration? duration;
  final String? mappedFilePath;

  AlbumTrackDraft copyWith({String? mappedFilePath}) {
    return AlbumTrackDraft(
      index: index,
      title: title,
      artist: artist,
      duration: duration,
      mappedFilePath: mappedFilePath ?? this.mappedFilePath,
    );
  }
}
