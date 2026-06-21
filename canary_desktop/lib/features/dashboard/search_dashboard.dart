part of '../../main.dart';

class SearchDashboardView extends StatelessWidget {
  const SearchDashboardView({
    required this.query,
    required this.tracks,
    required this.albums,
    required this.player,
    required this.onBack,
    required this.onOpenAlbum,
    super.key,
  });

  final String query;
  final List<CanaryTrack> tracks;
  final List<AlbumSummary> albums;
  final CanaryPlayerState player;
  final VoidCallback onBack;
  final ValueChanged<AlbumSummary> onOpenAlbum;

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeSearchText(query);
    final matchingTracks =
        tracks.where((track) {
          return searchMatches(normalized, [
            track.title,
            track.displayArtist,
            track.displayAlbum,
            track.genre,
          ]);
        }).toList()..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
    final matchingAlbums = albums.where((album) {
      return searchMatches(normalized, [album.title, album.artist]);
    }).toList();
    final byArtist = <String, List<CanaryTrack>>{};
    for (final track in tracks) {
      if (searchMatches(normalized, [track.displayArtist])) {
        byArtist.putIfAbsent(track.displayArtist, () => []).add(track);
      }
    }
    final artists = byArtist.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    final total =
        matchingTracks.length + matchingAlbums.length + artists.length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: DashboardBackHeader(
            title: 'Search',
            subtitle: total == 0
                ? 'No results for "$query"'
                : '$total results for "$query"',
            onBack: onBack,
          ),
        ),
        if (matchingAlbums.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SearchSectionTitle('Albums')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 246,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: matchingAlbums.length,
                separatorBuilder: (_, _) => const SizedBox(width: 20),
                itemBuilder: (context, index) => AlbumCard(
                  album: matchingAlbums[index],
                  size: ResponsiveShelf.cardWidth,
                  onTap: () => onOpenAlbum(matchingAlbums[index]),
                ),
              ),
            ),
          ),
        ],
        if (artists.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SearchSectionTitle('Artists')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 244,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: artists.length,
                separatorBuilder: (_, _) => const SizedBox(width: 20),
                itemBuilder: (context, index) {
                  final entry = artists[index];
                  final artistTracks = entry.value
                    ..sort(
                      (a, b) => a.title.toLowerCase().compareTo(
                        b.title.toLowerCase(),
                      ),
                    );
                  return SizedBox(
                    width: 178,
                    child: ArtistCard(
                      artist: entry.key,
                      trackCount: artistTracks.length,
                      coverTrack: artistTracks.first,
                      onTap: () => playTrackOrWarn(
                        context,
                        player,
                        artistTracks.first,
                        queue: artistTracks,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
        if (matchingTracks.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SearchSectionTitle('Songs')),
          SliverList.builder(
            itemCount: matchingTracks.length,
            itemBuilder: (context, index) {
              final track = matchingTracks[index];
              return TrackRow(
                track: track,
                onTap: () => playTrackOrWarn(
                  context,
                  player,
                  track,
                  queue: matchingTracks,
                ),
              );
            },
          ),
        ],
        if (total == 0)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'Try a song, artist, album, or genre.',
                style: TextStyle(
                  color: CanaryTheme.muted.withValues(alpha: .82),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class SearchSectionTitle extends StatelessWidget {
  const SearchSectionTitle(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 12),
      child: Text(
        label,
        style: const TextStyle(
          color: CanaryTheme.text,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
