part of '../main.dart';

class CanaryImage extends StatelessWidget {
  const CanaryImage({
    required this.pathOrUrl,
    required this.fallback,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String pathOrUrl;
  final Widget fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final path = pathOrUrl.replaceFirst('file://', '');
    if (path.startsWith('/')) {
      final file = File(path);
      if (!file.existsSync()) return fallback;
      return Image.file(file, fit: fit, errorBuilder: (_, _, _) => fallback);
    }
    return Image.network(
      pathOrUrl,
      fit: fit,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class CoverPreview extends StatelessWidget {
  const CoverPreview({required this.coverUrl, super.key});

  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    final url = coverUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 64,
        height: 64,
        color: CanaryTheme.honey,
        child: url == null
            ? const Icon(Icons.album_rounded, color: CanaryTheme.amber)
            : CanaryImage(
                pathOrUrl: url,
                fit: BoxFit.cover,
                fallback: const Icon(
                  Icons.album_rounded,
                  color: CanaryTheme.amber,
                ),
              ),
      ),
    );
  }
}

class CoverTile extends StatelessWidget {
  const CoverTile({required this.track, required this.size, super.key});

  final CanaryTrack track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final coverUrl = track.cover.sourceUrl;
    final fallback = _FallbackCover(
      track: track,
      size: size,
      colors: _coverColors(track.genre),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: coverUrl == null || coverUrl.isEmpty
            ? fallback
            : CanaryImage(
                pathOrUrl: coverUrl,
                fit: BoxFit.cover,
                fallback: fallback,
              ),
      ),
    );
  }

  List<Color> _coverColors(String genre) {
    return switch (genre) {
      'Lo-Fi' => const [Color(0xFFE3F2B4), Color(0xFFC8DA84)],
      'Electronic' => const [Color(0xFFC9F4EE), Color(0xFFA7DAD4)],
      'Hip-Hop' => const [Color(0xFFFFE492), Color(0xFFEFB36B)],
      'R&B' => const [Color(0xFFFFD1DF), Color(0xFFEAB0C3)],
      _ => const [CanaryTheme.honey, CanaryTheme.canary],
    };
  }
}

class _FallbackCover extends StatelessWidget {
  const _FallbackCover({
    required this.track,
    required this.size,
    required this.colors,
  });

  final CanaryTrack track;
  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Text(
          track.title.characters.first.toUpperCase(),
          style: TextStyle(
            fontSize: size * .42,
            fontWeight: FontWeight.w900,
            color: CanaryTheme.text.withValues(alpha: .86),
          ),
        ),
      ),
    );
  }
}

class ArtistInline extends StatelessWidget {
  const ArtistInline({required this.track, super.key});

  final CanaryTrack track;

  @override
  Widget build(BuildContext context) {
    final image = track.artistImageUrl;
    return Row(
      children: [
        ClipOval(
          child: SizedBox(
            width: 28,
            height: 28,
            child: image == null || image.isEmpty
                ? Container(
                    color: CanaryTheme.honey,
                    child: const Icon(
                      Icons.person_rounded,
                      size: 17,
                      color: CanaryTheme.amber,
                    ),
                  )
                : CanaryImage(
                    pathOrUrl: image,
                    fit: BoxFit.cover,
                    fallback: Container(
                      color: CanaryTheme.honey,
                      child: const Icon(
                        Icons.person_rounded,
                        size: 17,
                        color: CanaryTheme.amber,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            track.displayArtist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: CanaryTheme.muted),
          ),
        ),
      ],
    );
  }
}

class ArtistAvatar extends StatelessWidget {
  const ArtistAvatar({required this.track, required this.size, super.key});

  final CanaryTrack track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = track.artistImageUrl;
    final fallback = Container(
      color: CanaryTheme.honey,
      child: Icon(
        Icons.person_rounded,
        size: size * .56,
        color: CanaryTheme.amber,
      ),
    );
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: image == null || image.isEmpty
            ? fallback
            : CanaryImage(
                pathOrUrl: image,
                fit: BoxFit.cover,
                fallback: fallback,
              ),
      ),
    );
  }
}

class MetadataCacheCard extends StatelessWidget {
  const MetadataCacheCard({required this.policyLabel, super.key});

  final String policyLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CanaryTheme.canary.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CanaryTheme.canary.withValues(alpha: .32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cover Cache',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: CanaryTheme.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            policyLabel,
            style: const TextStyle(color: CanaryTheme.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 30, bottom: 14),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: CanaryTheme.text,
        ),
      ),
    );
  }
}

class RailButton extends StatelessWidget {
  const RailButton({
    required this.icon,
    required this.onTap,
    this.highlighted = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: highlighted
              ? const LinearGradient(
                  colors: [CanaryTheme.canary, CanaryTheme.amber],
                )
              : null,
          color: highlighted ? null : Colors.white.withValues(alpha: .64),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: CanaryTheme.canary.withValues(alpha: .28),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: Icon(icon, color: CanaryTheme.text),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({required this.child, this.width, super.key});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: CanaryTheme.panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: CanaryTheme.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
