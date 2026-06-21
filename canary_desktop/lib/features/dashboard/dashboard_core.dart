part of '../../main.dart';

enum DashboardViewKind {
  home,
  library,
  recent,
  albums,
  album,
  artists,
  playlists,
  search,
}

class DashboardRoute {
  const DashboardRoute.home()
    : kind = DashboardViewKind.home,
      album = null,
      query = '';

  const DashboardRoute.library()
    : kind = DashboardViewKind.library,
      album = null,
      query = '';

  const DashboardRoute.recent()
    : kind = DashboardViewKind.recent,
      album = null,
      query = '';

  const DashboardRoute.albums()
    : kind = DashboardViewKind.albums,
      album = null,
      query = '';

  const DashboardRoute.album(this.album)
    : kind = DashboardViewKind.album,
      query = '';

  const DashboardRoute.artists()
    : kind = DashboardViewKind.artists,
      album = null,
      query = '';

  const DashboardRoute.playlists()
    : kind = DashboardViewKind.playlists,
      album = null,
      query = '';

  const DashboardRoute.search(this.query)
    : kind = DashboardViewKind.search,
      album = null;

  final DashboardViewKind kind;
  final AlbumSummary? album;
  final String query;

  String get keyValue => '${kind.name}-${album?.id ?? query}';
}

class LibraryDashboard extends StatefulWidget {
  const LibraryDashboard({
    required this.library,
    required this.player,
    required this.route,
    required this.routeSerial,
    required this.onRouteChanged,
    super.key,
  });

  final LibraryController library;
  final CanaryPlayerState player;
  final DashboardRoute route;
  final int routeSerial;
  final ValueChanged<DashboardRoute> onRouteChanged;

  @override
  State<LibraryDashboard> createState() => _LibraryDashboardState();
}

class _LibraryDashboardState extends State<LibraryDashboard> {
  void openRoute(DashboardRoute next) {
    widget.onRouteChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CanaryTrack>>(
      stream: widget.library.tracks,
      initialData: widget.library.currentTracks,
      builder: (context, trackSnapshot) {
        final tracks = trackSnapshot.data ?? const <CanaryTrack>[];
        return StreamBuilder<List<AutoPlaylist>>(
          stream: widget.library.playlists,
          initialData: widget.library.currentPlaylists,
          builder: (context, playlistSnapshot) {
            final playlists = playlistSnapshot.data ?? const <AutoPlaylist>[];
            final albums = AlbumSummary.fromTracks(tracks, widget.library);
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(.08, 0),
                    end: Offset.zero,
                  ).animate(curved),
                  child: FadeTransition(opacity: curved, child: child),
                );
              },
              child: KeyedSubtree(
                key: ValueKey('${widget.route.keyValue}-${widget.routeSerial}'),
                child: switch (widget.route.kind) {
                  DashboardViewKind.home => HomeDashboardView(
                    library: widget.library,
                    player: widget.player,
                    tracks: tracks,
                    albums: albums,
                    playlists: playlists,
                    onOpenRecent: () =>
                        openRoute(const DashboardRoute.recent()),
                    onOpenAlbums: () =>
                        openRoute(const DashboardRoute.albums()),
                    onOpenAlbum: (album) =>
                        openRoute(DashboardRoute.album(album)),
                    onOpenPlaylists: () =>
                        openRoute(const DashboardRoute.playlists()),
                  ),
                  DashboardViewKind.library => LibraryDashboardView(
                    tracks: tracks,
                    player: widget.player,
                    onBack: () => openRoute(const DashboardRoute.home()),
                  ),
                  DashboardViewKind.recent => RecentDashboardView(
                    tracks: tracks,
                    player: widget.player,
                    onBack: () => openRoute(const DashboardRoute.home()),
                  ),
                  DashboardViewKind.albums => AlbumsDashboardView(
                    albums: albums,
                    onBack: () => openRoute(const DashboardRoute.home()),
                    onOpenAlbum: (album) =>
                        openRoute(DashboardRoute.album(album)),
                  ),
                  DashboardViewKind.artists => ArtistsDashboardView(
                    tracks: tracks,
                    player: widget.player,
                    onBack: () => openRoute(const DashboardRoute.home()),
                  ),
                  DashboardViewKind.album => AlbumDashboardView(
                    album:
                        firstWhereOrNull(
                          albums,
                          (album) => album.id == widget.route.album!.id,
                        ) ??
                        widget.route.album!,
                    player: widget.player,
                    library: widget.library,
                    onBack: () => openRoute(const DashboardRoute.home()),
                  ),
                  DashboardViewKind.playlists => PlaylistsDashboardView(
                    playlists: playlists,
                    onBack: () => openRoute(const DashboardRoute.home()),
                  ),
                  DashboardViewKind.search => SearchDashboardView(
                    query: widget.route.query,
                    tracks: tracks,
                    albums: albums,
                    player: widget.player,
                    onBack: () => openRoute(const DashboardRoute.home()),
                    onOpenAlbum: (album) =>
                        openRoute(DashboardRoute.album(album)),
                  ),
                },
              ),
            );
          },
        );
      },
    );
  }
}

class AlbumSummary {
  const AlbumSummary({
    required this.id,
    required this.title,
    required this.artist,
    required this.tracks,
    required this.look,
  });

  final String id;
  final String title;
  final String artist;
  final List<CanaryTrack> tracks;
  final AlbumLook look;

  CanaryTrack get coverTrack => tracks.first;

  static List<AlbumSummary> fromTracks(
    List<CanaryTrack> tracks,
    LibraryController library,
  ) {
    final grouped = <String, List<CanaryTrack>>{};
    for (final track in tracks) {
      if (isSingleAlbum(track.album)) continue;
      final key = normalizeAlbumKey(track.displayAlbum);
      grouped.putIfAbsent(key, () => []).add(track);
    }
    final albums =
        grouped.entries.map((entry) {
          final albumTracks = [...entry.value]
            ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
          final first = albumTracks.first;
          return AlbumSummary(
            id: entry.key,
            title: first.displayAlbum,
            artist: first.displayArtist,
            tracks: albumTracks,
            look: library.albumLookFor(
              albumId: entry.key,
              albumTitle: first.displayAlbum,
              artist: first.displayArtist,
              coverKey: first.cover.sourceUrl ?? first.cover.localPath,
            ),
          );
        }).toList()..sort(
          (a, b) => b.tracks.first.addedAt.compareTo(a.tracks.first.addedAt),
        );
    return albums;
  }
}

bool isSingleAlbum(String album) {
  final normalized = normalizeAlbumKey(album);
  return normalized.isEmpty ||
      normalized == 'single' ||
      normalized == 'unknown album' ||
      normalized.endsWith(' - single') ||
      normalized.endsWith(' single');
}

String normalizeAlbumKey(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String normalizeSearchText(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

bool searchMatches(String normalizedQuery, Iterable<String> values) {
  if (normalizedQuery.isEmpty) return false;
  return values.any((value) {
    return normalizeSearchText(value).contains(normalizedQuery);
  });
}

T? firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final value in values) {
    if (test(value)) return value;
  }
  return null;
}
