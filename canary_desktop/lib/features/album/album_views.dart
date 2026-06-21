part of '../../main.dart';

class AlbumDashboardView extends StatelessWidget {
  const AlbumDashboardView({
    required this.album,
    required this.player,
    required this.library,
    required this.onBack,
    super.key,
  });

  final AlbumSummary album;
  final CanaryPlayerState player;
  final LibraryController library;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final background = Color(album.look.background);
    final primary = Color(album.look.primary);
    final secondary = Color(album.look.secondary);
    final foreground = Color(album.look.text);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AlbumAtmosphere(
            album: album,
            background: background,
            primary: primary,
            secondary: secondary,
          ),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: onBack,
                        icon: Icon(Icons.arrow_back_rounded, color: foreground),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CoverTile(track: album.coverTrack, size: 220),
                          const SizedBox(width: 26),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  album.title,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: foreground,
                                    fontSize: 56,
                                    fontWeight: FontWeight.w900,
                                    height: .92,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                AlbumArtistLine(
                                  track: album.coverTrack,
                                  artist: album.artist,
                                  foreground: foreground,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${album.tracks.length} songs',
                                  style: TextStyle(
                                    color: foreground.withValues(alpha: .66),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    AlbumActionButton(
                                      icon: Icons.image_rounded,
                                      label: 'Album Art',
                                      foreground: foreground,
                                      onPressed: () => unawaited(
                                        changeAlbumArt(context, library, album),
                                      ),
                                    ),
                                    AlbumActionButton(
                                      icon: Icons.playlist_add_rounded,
                                      label: 'Add Songs',
                                      foreground: foreground,
                                      onPressed: () => unawaited(
                                        showAddToAlbumDialog(
                                          context,
                                          library,
                                          album,
                                        ),
                                      ),
                                    ),
                                    AlbumActionButton(
                                      icon: Icons.delete_outline_rounded,
                                      label: 'Delete Album',
                                      foreground: foreground,
                                      onPressed: () => unawaited(
                                        confirmDeleteAlbum(
                                          context,
                                          library,
                                          album,
                                          onBack,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(26, 0, 26, 28),
                sliver: SliverList.builder(
                  itemCount: album.tracks.length,
                  itemBuilder: (context, index) {
                    final track = album.tracks[index];
                    return AlbumTrackRow(
                      track: track,
                      foreground: foreground,
                      onTap: () => playTrackOrWarn(
                        context,
                        player,
                        track,
                        queue: album.tracks,
                      ),
                      onUnlink: () => unawaited(
                        confirmUnlinkTrack(context, library, track),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AlbumAtmosphere extends StatelessWidget {
  const AlbumAtmosphere({
    required this.album,
    required this.background,
    required this.primary,
    required this.secondary,
    super.key,
  });

  final AlbumSummary album;
  final Color background;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primary.withValues(alpha: .26),
                background,
                secondary.withValues(alpha: .38),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: .28,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Transform.scale(
                scale: 1.03,
                child: CoverTile(track: album.coverTrack, size: 900),
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-.72, -.52),
              radius: .82,
              colors: [primary.withValues(alpha: .32), Colors.transparent],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: .06),
                Colors.black.withValues(alpha: .18),
                Colors.black.withValues(alpha: .38),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AlbumActionButton extends StatelessWidget {
  const AlbumActionButton({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        side: BorderSide(color: foreground.withValues(alpha: .28)),
        backgroundColor: foreground.withValues(alpha: .08),
      ),
    );
  }
}

class AlbumArtistLine extends StatelessWidget {
  const AlbumArtistLine({
    required this.track,
    required this.artist,
    required this.foreground,
    super.key,
  });

  final CanaryTrack track;
  final String artist;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final image = track.artistImageUrl;
    return Row(
      children: [
        ClipOval(
          child: SizedBox(
            width: 38,
            height: 38,
            child: image == null || image.isEmpty
                ? Container(
                    color: foreground.withValues(alpha: .14),
                    child: Icon(
                      Icons.person_rounded,
                      color: foreground.withValues(alpha: .72),
                      size: 22,
                    ),
                  )
                : CanaryImage(
                    pathOrUrl: image,
                    fit: BoxFit.cover,
                    fallback: Container(
                      color: foreground.withValues(alpha: .14),
                      child: Icon(
                        Icons.person_rounded,
                        color: foreground.withValues(alpha: .72),
                        size: 22,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          artist,
          style: TextStyle(
            color: foreground,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class AlbumTrackRow extends StatelessWidget {
  const AlbumTrackRow({
    required this.track,
    required this.foreground,
    required this.onTap,
    required this.onUnlink,
    super.key,
  });

  final CanaryTrack track;
  final Color foreground;
  final VoidCallback onTap;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              CoverTile(track: track, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(
                width: 230,
                child: Text(
                  track.displayArtist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: foreground.withValues(alpha: .68)),
                ),
              ),
              SizedBox(
                width: 160,
                child: Text(
                  track.genre,
                  style: TextStyle(color: foreground.withValues(alpha: .62)),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  formatDuration(track.duration),
                  textAlign: TextAlign.right,
                  style: TextStyle(color: foreground.withValues(alpha: .62)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove from Canary',
                onPressed: onUnlink,
                icon: Icon(
                  Icons.remove_circle_outline_rounded,
                  color: foreground.withValues(alpha: .70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> confirmUnlinkTrack(
  BuildContext context,
  LibraryController library,
  CanaryTrack track,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: CanaryTheme.background,
      title: const Text('Remove from Canary?'),
      content: Text(
        'This removes "${track.title}" from Canary\'s library. The audio file itself will not be deleted.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await library.unlinkTrack(track.id);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Removed "${track.title}" from Canary.')),
  );
}

Future<String?> pickAlbumArtImagePath() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    for (final path in result?.paths ?? const <String?>[]) {
      if (path != null && path.isNotEmpty) return path;
    }
    return null;
  } catch (_) {
    return null;
  }
}

Future<void> changeAlbumArt(
  BuildContext context,
  LibraryController library,
  AlbumSummary album,
) async {
  final mode = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: CanaryTheme.background,
      title: Text('Album Art for ${album.title}'),
      content: const Text(
        'Choose a local image, or search online using the album metadata.',
        style: TextStyle(color: CanaryTheme.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context, 'local'),
          icon: const Icon(Icons.folder_open_rounded),
          label: const Text('Choose Image'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, 'search'),
          icon: const Icon(Icons.manage_search_rounded),
          label: const Text('Search Metadata'),
        ),
      ],
    ),
  );
  if (mode == null || !context.mounted) return;
  final imagePath = mode == 'local'
      ? await pickAlbumArtImagePath()
      : await searchAlbumArtImagePath(context, library, album);
  if (imagePath == null || imagePath.isEmpty) return;
  await library.updateAlbumCover(albumId: album.id, imagePath: imagePath);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Updated artwork for "${album.title}".')),
  );
}

Future<String?> searchAlbumArtImagePath(
  BuildContext context,
  LibraryController library,
  AlbumSummary album,
) async {
  final albumController = TextEditingController(text: album.title);
  final artistController = TextEditingController(text: album.artist);
  MetadataDraft? draft;
  var loading = false;
  try {
    return await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> search() async {
            if (loading) return;
            setState(() => loading = true);
            try {
              final next = await library.previewAlbumMetadata(
                title: album.coverTrack.title,
                artist: artistController.text,
                album: albumController.text,
                fallback: MetadataDraft(
                  title: album.coverTrack.title,
                  artist: artistController.text.trim().isEmpty
                      ? album.artist
                      : artistController.text.trim(),
                  album: albumController.text.trim().isEmpty
                      ? album.title
                      : albumController.text.trim(),
                  genre: album.coverTrack.genre,
                  confidence: .50,
                  coverUrl:
                      album.coverTrack.cover.sourceUrl ??
                      album.coverTrack.cover.localPath,
                  sourceLabel: 'Current album',
                  artistImageUrl: album.coverTrack.artistImageUrl,
                ),
              );
              setState(() {
                draft = next;
                loading = false;
              });
            } catch (_) {
              setState(() {
                draft = null;
                loading = false;
              });
            }
          }

          return AlertDialog(
            backgroundColor: CanaryTheme.background,
            title: const Text('Search Album Art'),
            content: SizedBox(
              width: 620,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: albumController,
                          decoration: const InputDecoration(
                            labelText: 'Album name',
                          ),
                          onSubmitted: (_) => unawaited(search()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: artistController,
                          decoration: const InputDecoration(
                            labelText: 'Artist',
                          ),
                          onSubmitted: (_) => unawaited(search()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        tooltip: 'Search',
                        onPressed: loading ? null : () => unawaited(search()),
                        icon: loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (draft == null)
                    Container(
                      height: 130,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .54),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: CanaryTheme.border),
                      ),
                      child: const Text(
                        'Search to preview matching album art.',
                        style: TextStyle(color: CanaryTheme.muted),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .70),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: CanaryTheme.border),
                      ),
                      child: Row(
                        children: [
                          CoverPreview(coverUrl: draft!.coverUrl),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${draft!.album}\n${draft!.artist}\n${draft!.sourceLabel} • ${(draft!.confidence * 100).round()}%',
                              style: const TextStyle(color: CanaryTheme.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: draft?.coverUrl == null
                    ? null
                    : () => Navigator.pop(context, draft!.coverUrl),
                child: const Text('Use Cover'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    albumController.dispose();
    artistController.dispose();
  }
}

Future<void> showAddToAlbumDialog(
  BuildContext context,
  LibraryController library,
  AlbumSummary album,
) async {
  final albumTrackIds = album.tracks.map((track) => track.id).toSet();
  final available =
      library.currentTracks
          .where((track) => !albumTrackIds.contains(track.id))
          .toList()
        ..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
  final selected = <String>{};
  final added = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: CanaryTheme.background,
        title: Text('Add Songs to ${album.title}'),
        content: SizedBox(
          width: 720,
          height: 520,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      available.isEmpty
                          ? 'No existing songs outside this album yet.'
                          : 'Select existing Canary songs, or import new audio files directly into this album.',
                      style: const TextStyle(color: CanaryTheme.muted),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final paths = await pickAudioPathsWithFallback(context);
                      if (paths.isEmpty || !context.mounted) return;
                      await showDialog<void>(
                        context: context,
                        builder: (context) => ImportConfirmationDialog(
                          library: library,
                          paths: paths,
                          targetAlbum: album,
                        ),
                      );
                      if (context.mounted) Navigator.pop(context, true);
                    },
                    icon: const Icon(Icons.audio_file_rounded),
                    label: const Text('Import New'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: available.isEmpty
                    ? const Center(
                        child: Text(
                          'Import new songs to add more music here.',
                          style: TextStyle(color: CanaryTheme.muted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: available.length,
                        itemBuilder: (context, index) {
                          final track = available[index];
                          final checked = selected.contains(track.id);
                          return CheckboxListTile(
                            value: checked,
                            onChanged: (value) => setState(() {
                              if (value ?? false) {
                                selected.add(track.id);
                              } else {
                                selected.remove(track.id);
                              }
                            }),
                            secondary: CoverTile(track: track, size: 42),
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${track.displayArtist} • ${track.displayAlbum}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () async {
                    await library.moveTracksToAlbum(
                      albumId: album.id,
                      albumTitle: album.title,
                      trackIds: selected.toList(),
                    );
                    if (context.mounted) Navigator.pop(context, true);
                  },
            child: Text('Add ${selected.length}'),
          ),
        ],
      ),
    ),
  );
  if (added != true || !context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('Updated "${album.title}".')));
}

Future<void> confirmDeleteAlbum(
  BuildContext context,
  LibraryController library,
  AlbumSummary album,
  VoidCallback onDeleted,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: CanaryTheme.background,
      title: Text('Delete "${album.title}"?'),
      content: Text(
        'This removes ${album.tracks.length} song${album.tracks.length == 1 ? '' : 's'} from Canary. The audio files themselves will not be deleted.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete Album'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await library.deleteAlbum(album.id);
  if (!context.mounted) return;
  onDeleted();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Deleted "${album.title}" from Canary.')),
  );
}

ImportCandidate candidateForAlbum(
  ImportCandidate candidate,
  AlbumSummary album,
) {
  final fallback = candidate.draft;
  final draft =
      fallback ??
      MetadataDraft(
        title: candidate.currentTitle,
        artist: candidate.currentArtist,
        album: album.title,
        genre: 'Unsorted',
        confidence: .42,
        coverUrl: album.coverTrack.cover.sourceUrl,
        sourceLabel: 'Current file metadata + album',
        artistImageUrl: null,
      );
  return candidate.copyWith(
    draft: draft.copyWith(
      album: album.title,
      coverUrl:
          draft.coverUrl ??
          album.coverTrack.cover.sourceUrl ??
          album.coverTrack.cover.localPath,
      sourceLabel: '${draft.sourceLabel} + ${album.title}',
    ),
    status: 'Ready for ${album.title}',
  );
}

Future<void> showAlbumTracksDialog(
  BuildContext context,
  AlbumSummary album,
  CanaryPlayerState player,
  LibraryController library,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: CanaryTheme.background,
      title: Text(album.title),
      content: SizedBox(
        width: 820,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CoverTile(track: album.coverTrack, size: 112),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.artist,
                        style: const TextStyle(
                          color: CanaryTheme.muted,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${album.tracks.length} songs',
                        style: const TextStyle(
                          color: CanaryTheme.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView.builder(
                itemCount: album.tracks.length,
                itemBuilder: (context, index) {
                  final track = album.tracks[index];
                  return TrackRow(
                    track: track,
                    onTap: () {
                      Navigator.pop(dialogContext);
                      unawaited(
                        playTrackOrWarn(
                          context,
                          player,
                          track,
                          queue: album.tracks,
                        ),
                      );
                    },
                    onUnlink: () => unawaited(
                      confirmUnlinkTrack(dialogContext, library, track),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
