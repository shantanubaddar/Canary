part of '../../main.dart';

class HeaderSection extends StatelessWidget {
  const HeaderSection({
    required this.onImportFiles,
    required this.onAddSong,
    required this.onAlbumImport,
    super.key,
  });

  final VoidCallback onImportFiles;
  final VoidCallback onAddSong;
  final VoidCallback onAlbumImport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Desktop Library',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: CanaryTheme.text,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Import audio, review suggested covers and metadata, then confirm before Canary writes anything permanent.',
                  style: TextStyle(color: CanaryTheme.muted, fontSize: 16),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onAlbumImport,
                icon: const Icon(Icons.playlist_add_check_rounded),
                label: const Text('Playlist Album'),
              ),
              OutlinedButton.icon(
                onPressed: onAddSong,
                icon: const Icon(Icons.link_rounded),
                label: const Text('Song Lookup'),
              ),
              FilledButton.icon(
                onPressed: onImportFiles,
                icon: const Icon(Icons.audio_file_rounded),
                label: const Text('Import Files'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HomeDashboardView extends StatelessWidget {
  const HomeDashboardView({
    required this.library,
    required this.player,
    required this.tracks,
    required this.albums,
    required this.playlists,
    required this.onOpenRecent,
    required this.onOpenAlbums,
    required this.onOpenAlbum,
    required this.onOpenPlaylists,
    super.key,
  });

  final LibraryController library;
  final CanaryPlayerState player;
  final List<CanaryTrack> tracks;
  final List<AlbumSummary> albums;
  final List<AutoPlaylist> playlists;
  final VoidCallback onOpenRecent;
  final VoidCallback onOpenAlbums;
  final ValueChanged<AlbumSummary> onOpenAlbum;
  final VoidCallback onOpenPlaylists;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: HeaderSection(
            onImportFiles: () => showImportFilesDialog(context, library),
            onAddSong: () => showAddSongDialog(context, library),
            onAlbumImport: () => showAlbumImportDialog(context, library),
          ),
        ),
        SliverToBoxAdapter(child: SectionTitle('Recently Added')),
        SliverToBoxAdapter(
          child: TrackCardShelf(
            tracks: tracks,
            onSeeMore: onOpenRecent,
            onTrackTap: (track) =>
                playTrackOrWarn(context, player, track, queue: tracks),
          ),
        ),
        if (albums.isNotEmpty) ...[
          SliverToBoxAdapter(child: SectionTitle('Albums')),
          SliverToBoxAdapter(
            child: AlbumShelf(
              albums: albums,
              onSeeMore: onOpenAlbums,
              onAlbumTap: onOpenAlbum,
            ),
          ),
        ],
        SliverToBoxAdapter(child: SectionTitle('Playlists')),
        SliverToBoxAdapter(
          child: PlaylistStrip(
            playlists: playlists,
            onSeeMore: onOpenPlaylists,
          ),
        ),
      ],
    );
  }
}

class DashboardBackHeader extends StatelessWidget {
  const DashboardBackHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.foreground = CanaryTheme.text,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: Icon(Icons.arrow_back_rounded, color: foreground),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: foreground.withValues(alpha: .68),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RecentDashboardView extends StatelessWidget {
  const RecentDashboardView({
    required this.tracks,
    required this.player,
    required this.onBack,
    super.key,
  });

  final List<CanaryTrack> tracks;
  final CanaryPlayerState player;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final recent = [...tracks]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final topTwenty = recent.take(20).toList();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: DashboardBackHeader(
            title: 'Recently Added',
            subtitle: 'Top ${topTwenty.length} songs added to Canary',
            onBack: onBack,
          ),
        ),
        SliverList.builder(
          itemCount: topTwenty.length,
          itemBuilder: (context, index) {
            final track = topTwenty[index];
            return TrackRow(
              track: track,
              onTap: () =>
                  playTrackOrWarn(context, player, track, queue: topTwenty),
            );
          },
        ),
      ],
    );
  }
}

class LibraryDashboardView extends StatelessWidget {
  const LibraryDashboardView({
    required this.tracks,
    required this.player,
    required this.onBack,
    super.key,
  });

  final List<CanaryTrack> tracks;
  final CanaryPlayerState player;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final sorted = [...tracks]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: DashboardBackHeader(
            title: 'Library',
            subtitle: '${sorted.length} songs in Canary',
            onBack: onBack,
          ),
        ),
        SliverList.builder(
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final track = sorted[index];
            return TrackRow(
              track: track,
              onTap: () =>
                  playTrackOrWarn(context, player, track, queue: sorted),
            );
          },
        ),
      ],
    );
  }
}

class ArtistsDashboardView extends StatelessWidget {
  const ArtistsDashboardView({
    required this.tracks,
    required this.player,
    required this.onBack,
    super.key,
  });

  final List<CanaryTrack> tracks;
  final CanaryPlayerState player;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final byArtist = <String, List<CanaryTrack>>{};
    for (final track in tracks) {
      byArtist.putIfAbsent(track.displayArtist, () => []).add(track);
    }
    final artists = byArtist.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: DashboardBackHeader(
            title: 'Artists',
            subtitle: '${artists.length} artists in Canary',
            onBack: onBack,
          ),
        ),
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = constraints.crossAxisExtent / 3;
            return SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: (cellWidth * .78) + 72,
                crossAxisSpacing: 0,
                mainAxisSpacing: 0,
              ),
              itemCount: artists.length,
              itemBuilder: (context, index) {
                final entry = artists[index];
                final artistTracks = entry.value
                  ..sort(
                    (a, b) =>
                        a.title.toLowerCase().compareTo(b.title.toLowerCase()),
                  );
                final first = artistTracks.first;
                return ArtistCard(
                  artist: entry.key,
                  trackCount: artistTracks.length,
                  coverTrack: first,
                  onTap: () => playTrackOrWarn(
                    context,
                    player,
                    first,
                    queue: artistTracks,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class AlbumsDashboardView extends StatelessWidget {
  const AlbumsDashboardView({
    required this.albums,
    required this.onBack,
    required this.onOpenAlbum,
    super.key,
  });

  final List<AlbumSummary> albums;
  final VoidCallback onBack;
  final ValueChanged<AlbumSummary> onOpenAlbum;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: DashboardBackHeader(
            title: 'Albums',
            subtitle: '${albums.length} albums in Canary',
            onBack: onBack,
          ),
        ),
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = constraints.crossAxisExtent / 3;
            return SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: cellWidth + 58,
                crossAxisSpacing: 0,
                mainAxisSpacing: 0,
              ),
              itemCount: albums.length,
              itemBuilder: (context, index) => AlbumCard(
                album: albums[index],
                onTap: () => onOpenAlbum(albums[index]),
              ),
            );
          },
        ),
      ],
    );
  }
}

class PlaylistsDashboardView extends StatelessWidget {
  const PlaylistsDashboardView({
    required this.playlists,
    required this.onBack,
    super.key,
  });

  final List<AutoPlaylist> playlists;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: DashboardBackHeader(
            title: 'Playlists',
            subtitle: '${playlists.length} auto-built mixes',
            onBack: onBack,
          ),
        ),
        SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 208,
            mainAxisExtent: 246,
            crossAxisSpacing: 20,
            mainAxisSpacing: 18,
          ),
          itemCount: playlists.length,
          itemBuilder: (context, index) =>
              PlaylistCard(playlist: playlists[index]),
        ),
      ],
    );
  }
}

class PlaylistStrip extends StatelessWidget {
  const PlaylistStrip({
    required this.playlists,
    required this.onSeeMore,
    super.key,
  });

  final List<AutoPlaylist> playlists;
  final VoidCallback onSeeMore;

  @override
  Widget build(BuildContext context) {
    return ResponsiveShelf(
      itemCount: playlists.length,
      itemBuilder: (context, index) => PlaylistCard(playlist: playlists[index]),
      seeMoreBuilder: (context) => SeeMoreCard(
        title: 'See More',
        subtitle: 'All playlists',
        icon: Icons.arrow_forward_rounded,
        onTap: onSeeMore,
      ),
    );
  }
}

class PlaylistCard extends StatelessWidget {
  const PlaylistCard({required this.playlist, super.key});

  final AutoPlaylist playlist;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 178,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 178,
            height: 178,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Color(playlist.accent).withValues(alpha: .34),
              border: Border.all(color: CanaryTheme.border),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Icon(
                Icons.auto_awesome_rounded,
                color: CanaryTheme.text.withValues(alpha: .72),
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            playlist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: CanaryTheme.text,
            ),
          ),
          Text(
            '${playlist.trackIds.length} songs',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: CanaryTheme.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

Future<void> playTrackOrWarn(
  BuildContext context,
  CanaryPlayerState player,
  CanaryTrack track, {
  required List<CanaryTrack> queue,
}) async {
  final played = await player.load(track, queue: queue);
  if (played || !context.mounted) return;
  final path = track.localPath;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        path == null || path.isEmpty
            ? 'No local file is linked for "${track.title}".'
            : 'Canary cannot play "${track.title}" because the saved file path is missing.',
      ),
      action: SnackBarAction(label: 'OK', onPressed: () {}),
    ),
  );
}

class TrackCardShelf extends StatelessWidget {
  const TrackCardShelf({
    required this.tracks,
    required this.onSeeMore,
    required this.onTrackTap,
    super.key,
  });

  final List<CanaryTrack> tracks;
  final VoidCallback onSeeMore;
  final ValueChanged<CanaryTrack> onTrackTap;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return Container(
        height: 178,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .52),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: CanaryTheme.border),
        ),
        child: const Text(
          'Import music to build your library.',
          style: TextStyle(color: CanaryTheme.muted),
        ),
      );
    }
    return ResponsiveShelf(
      itemCount: tracks.length,
      itemBuilder: (context, index) => TrackCoverCard(
        track: tracks[index],
        onTap: () => onTrackTap(tracks[index]),
      ),
      seeMoreBuilder: (context) => SeeMoreCard(
        title: 'See More',
        subtitle: 'Top 20 recently added',
        icon: Icons.arrow_forward_rounded,
        onTap: onSeeMore,
      ),
    );
  }
}

class AlbumShelf extends StatelessWidget {
  const AlbumShelf({
    required this.albums,
    required this.onSeeMore,
    required this.onAlbumTap,
    super.key,
  });

  final List<AlbumSummary> albums;
  final VoidCallback onSeeMore;
  final ValueChanged<AlbumSummary> onAlbumTap;

  @override
  Widget build(BuildContext context) {
    return ResponsiveShelf(
      itemCount: albums.length,
      itemBuilder: (context, index) => AlbumCard(
        album: albums[index],
        size: ResponsiveShelf.cardWidth,
        onTap: () => onAlbumTap(albums[index]),
      ),
      seeMoreBuilder: (context) => SeeMoreCard(
        title: 'See More',
        subtitle: 'All albums',
        icon: Icons.arrow_forward_rounded,
        onTap: onSeeMore,
      ),
    );
  }
}

class ResponsiveShelf extends StatelessWidget {
  const ResponsiveShelf({
    required this.itemCount,
    required this.itemBuilder,
    required this.seeMoreBuilder,
    super.key,
  });

  static const double cardWidth = 178;
  static const double gap = 20;

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final WidgetBuilder seeMoreBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final slots = (available / (cardWidth + gap)).floor().clamp(1, 12);
        final needsMore = itemCount > slots;
        final visibleItems = needsMore
            ? (slots - 1).clamp(0, itemCount)
            : itemCount;
        final children = <Widget>[
          for (var index = 0; index < visibleItems; index++)
            itemBuilder(context, index),
          if (needsMore) seeMoreBuilder(context),
        ];
        return SizedBox(
          height: 246,
          child: Wrap(spacing: gap, runSpacing: 0, children: children),
        );
      },
    );
  }
}

class TrackCoverCard extends StatelessWidget {
  const TrackCoverCard({required this.track, required this.onTap, super.key});

  final CanaryTrack track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 178,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverTile(track: track, size: 178),
            const SizedBox(height: 9),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: CanaryTheme.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              track.displayArtist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: CanaryTheme.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class AlbumCard extends StatelessWidget {
  const AlbumCard({
    required this.album,
    required this.onTap,
    this.size,
    super.key,
  });

  final AlbumSummary album;
  final VoidCallback onTap;
  final double? size;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            size ??
            (constraints.maxWidth.isFinite ? constraints.maxWidth : 178.0);
        final coverSize = width;
        return SizedBox(
          width: width,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoverTile(track: album.coverTrack, size: coverSize),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CanaryTheme.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${album.artist} • ${album.tracks.length} songs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CanaryTheme.muted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ArtistCard extends StatelessWidget {
  const ArtistCard({
    required this.artist,
    required this.trackCount,
    required this.coverTrack,
    required this.onTap,
    super.key,
  });

  final String artist;
  final int trackCount;
  final CanaryTrack coverTrack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 240.0;
        final avatarSize = (width * .74).clamp(140.0, 300.0);
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: width,
            child: Column(
              children: [
                const SizedBox(height: 8),
                ArtistAvatar(track: coverTrack, size: avatarSize),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: CanaryTheme.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
                Text(
                  '$trackCount songs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CanaryTheme.muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SeeMoreCard extends StatelessWidget {
  const SeeMoreCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 178,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 178,
              height: 178,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .62),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CanaryTheme.border),
              ),
              child: Icon(
                icon,
                color: CanaryTheme.text.withValues(alpha: .68),
                size: 40,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: CanaryTheme.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: CanaryTheme.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class TrackRow extends StatelessWidget {
  const TrackRow({
    required this.track,
    required this.onTap,
    this.onUnlink,
    super.key,
  });

  final CanaryTrack track;
  final VoidCallback onTap;
  final VoidCallback? onUnlink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .62),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: CanaryTheme.border),
          ),
          child: Row(
            children: [
              CoverTile(track: track, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  track.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: CanaryTheme.text,
                  ),
                ),
              ),
              SizedBox(width: 230, child: ArtistInline(track: track)),
              SizedBox(
                width: 160,
                child: Text(
                  track.genre,
                  style: const TextStyle(color: CanaryTheme.muted),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  formatDuration(track.duration),
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: CanaryTheme.muted),
                ),
              ),
              if (onUnlink != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove from Canary',
                  onPressed: onUnlink,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showRecentlyAddedDialog(
  BuildContext context,
  LibraryController library,
  List<CanaryTrack> tracks,
  ValueChanged<CanaryTrack> onTrackTap,
) async {
  final recent = [...tracks]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  final topTwenty = recent.take(20).toList();
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: CanaryTheme.background,
      title: const Text('Recently Added'),
      content: SizedBox(
        width: 820,
        height: 560,
        child: ListView.builder(
          itemCount: topTwenty.length,
          itemBuilder: (context, index) {
            final track = topTwenty[index];
            return TrackRow(
              track: track,
              onTap: () {
                Navigator.pop(context);
                onTrackTap(track);
              },
              onUnlink: () =>
                  unawaited(confirmUnlinkTrack(context, library, track)),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> showAlbumsDialog(
  BuildContext context,
  List<AlbumSummary> albums,
  ValueChanged<AlbumSummary> onAlbumTap,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: CanaryTheme.background,
      title: const Text('Albums'),
      content: SizedBox(
        width: 820,
        height: 560,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 190,
            mainAxisExtent: 238,
            crossAxisSpacing: 20,
            mainAxisSpacing: 18,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return AlbumCard(
              album: album,
              onTap: () {
                Navigator.pop(context);
                onAlbumTap(album);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> showPlaylistsDialog(
  BuildContext context,
  List<AutoPlaylist> playlists,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: CanaryTheme.background,
      title: const Text('Playlists'),
      content: SizedBox(
        width: 820,
        height: 560,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 190,
            mainAxisExtent: 238,
            crossAxisSpacing: 20,
            mainAxisSpacing: 18,
          ),
          itemCount: playlists.length,
          itemBuilder: (context, index) =>
              PlaylistCard(playlist: playlists[index]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
