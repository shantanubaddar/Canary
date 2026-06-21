part of '../../main.dart';

class CanaryNowPlayingToast extends StatelessWidget {
  const CanaryNowPlayingToast({
    required this.track,
    required this.visible,
    required this.onTap,
    super.key,
  });

  final CanaryTrack? track;
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = track;
    return IgnorePointer(
      ignoring: !visible || current == null,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(1.12, 0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: visible ? 1 : 0,
          child: current == null
              ? const SizedBox.shrink()
              : Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                        child: Container(
                          width: 380,
                          height: 116,
                          decoration: BoxDecoration(
                            color: CanaryTheme.panel.withValues(alpha: .78),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: CanaryTheme.border),
                            boxShadow: [
                              BoxShadow(
                                color: CanaryTheme.text.withValues(alpha: .14),
                                blurRadius: 34,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if ((current.cover.sourceUrl ?? '').isNotEmpty)
                                Opacity(
                                  opacity: .42,
                                  child: CanaryImage(
                                    pathOrUrl: current.cover.sourceUrl!,
                                    fit: BoxFit.cover,
                                    fallback: const SizedBox.shrink(),
                                  ),
                                ),
                              BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 18,
                                  sigmaY: 18,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        CanaryTheme.background.withValues(
                                          alpha: .86,
                                        ),
                                        CanaryTheme.background.withValues(
                                          alpha: .70,
                                        ),
                                        CanaryTheme.text.withValues(alpha: .18),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    CoverTile(track: current, size: 82),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.graphic_eq_rounded,
                                                size: 16,
                                                color: CanaryTheme.amber,
                                              ),
                                              const SizedBox(width: 6),
                                              const Text(
                                                'NOW PLAYING',
                                                style: TextStyle(
                                                  color: CanaryTheme.amber,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              const Spacer(),
                                              Icon(
                                                Icons.open_in_new_rounded,
                                                size: 16,
                                                color: CanaryTheme.text
                                                    .withValues(alpha: .56),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            current.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: CanaryTheme.text,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              height: 1.05,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            current.displayArtist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: CanaryTheme.muted,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class FloatingVerticalPlayer extends StatefulWidget {
  const FloatingVerticalPlayer({
    required this.library,
    required this.player,
    required this.expandedNotifier,
    super.key,
  });

  final LibraryController library;
  final CanaryPlayerState player;
  final ValueNotifier<bool> expandedNotifier;

  @override
  State<FloatingVerticalPlayer> createState() => _FloatingVerticalPlayerState();
}

class _FloatingVerticalPlayerState extends State<FloatingVerticalPlayer> {
  bool expanded = false;
  late CanaryPlayerSnapshot playerSnapshot;
  late final ValueNotifier<Duration> positionNotifier;
  late final ValueNotifier<Duration> durationNotifier;
  late final ValueNotifier<double> volumeNotifier;
  StreamSubscription<CanaryPlayerSnapshot>? playerSubscription;

  @override
  void initState() {
    super.initState();
    expanded = widget.expandedNotifier.value;
    playerSnapshot = widget.player.current;
    positionNotifier = ValueNotifier(playerSnapshot.position);
    durationNotifier = ValueNotifier(_effectiveDuration(playerSnapshot));
    volumeNotifier = ValueNotifier(playerSnapshot.volume);
    widget.expandedNotifier.addListener(_syncExpanded);
    _listenToPlayer();
  }

  @override
  void didUpdateWidget(FloatingVerticalPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expandedNotifier != widget.expandedNotifier) {
      oldWidget.expandedNotifier.removeListener(_syncExpanded);
      expanded = widget.expandedNotifier.value;
      widget.expandedNotifier.addListener(_syncExpanded);
    }
    if (oldWidget.player != widget.player) {
      unawaited(playerSubscription?.cancel());
      playerSnapshot = widget.player.current;
      positionNotifier.value = playerSnapshot.position;
      durationNotifier.value = _effectiveDuration(playerSnapshot);
      volumeNotifier.value = playerSnapshot.volume;
      _listenToPlayer();
    }
  }

  @override
  void dispose() {
    widget.expandedNotifier.removeListener(_syncExpanded);
    unawaited(playerSubscription?.cancel());
    positionNotifier.dispose();
    durationNotifier.dispose();
    volumeNotifier.dispose();
    super.dispose();
  }

  void _listenToPlayer() {
    playerSubscription = widget.player.snapshots.listen((snapshot) {
      positionNotifier.value = snapshot.position;
      durationNotifier.value = _effectiveDuration(snapshot);
      volumeNotifier.value = snapshot.volume;

      final previous = playerSnapshot;
      playerSnapshot = snapshot;
      final trackChanged = previous.track?.id != snapshot.track?.id;
      final playStateChanged = previous.isPlaying != snapshot.isPlaying;
      final durationChanged = previous.duration != snapshot.duration;
      if (mounted && (trackChanged || playStateChanged || durationChanged)) {
        setState(() {});
      }
    });
  }

  Duration _effectiveDuration(CanaryPlayerSnapshot snapshot) {
    return snapshot.duration == Duration.zero
        ? snapshot.track?.duration ?? Duration.zero
        : snapshot.duration;
  }

  void _syncExpanded() {
    if (mounted && expanded != widget.expandedNotifier.value) {
      setState(() => expanded = widget.expandedNotifier.value);
    }
  }

  void _setExpanded(bool value) {
    widget.expandedNotifier.value = value;
    if (mounted) setState(() => expanded = value);
  }

  @override
  Widget build(BuildContext context) {
    final state = playerSnapshot;
    final track = state.track;
    final activeLook = track == null || isSingleAlbum(track.album)
        ? null
        : widget.library.albumLookFor(
            albumId: normalizeAlbumKey(track.displayAlbum),
            albumTitle: track.displayAlbum,
            artist: track.displayArtist,
            coverKey: track.cover.sourceUrl ?? track.cover.localPath,
          );
    final barTint = activeLook == null
        ? Colors.white.withValues(alpha: .56)
        : Color(activeLook.background).withValues(alpha: .62);
    final borderTint = activeLook == null
        ? CanaryTheme.border
        : Color(activeLook.primary).withValues(alpha: .34);
    final accentTint = activeLook == null
        ? CanaryTheme.coral
        : Color(activeLook.primary);
    final controlFill = activeLook == null
        ? CanaryTheme.text.withValues(alpha: .12)
        : accentTint.withValues(alpha: .20);
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final wingWidth = (screenWidth * .25).clamp(340.0, 480.0);
        final shellWidth = wingWidth + 118;
        return SizedBox(
          width: shellWidth,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            alignment: Alignment.centerRight,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 210),
                curve: Curves.easeOutQuart,
                right: expanded ? 86 : -wingWidth - 24,
                top: 0,
                bottom: 0,
                child: RepaintBoundary(
                  child: ExpandedPlayerWing(
                    width: wingWidth,
                    track: track,
                    positionListenable: positionNotifier,
                    durationListenable: durationNotifier,
                    volumeListenable: volumeNotifier,
                    onSeek: widget.player.seek,
                    onVolumeChanged: widget.player.setVolume,
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(44),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Container(
                    width: 74,
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                      horizontal: 9,
                    ),
                    decoration: BoxDecoration(
                      color: barTint,
                      borderRadius: BorderRadius.circular(44),
                      border: Border.all(color: borderTint),
                      boxShadow: [
                        BoxShadow(
                          color: CanaryTheme.text.withValues(alpha: .10),
                          blurRadius: 30,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (track != null) ...[
                          CoverTile(track: track, size: 46),
                          const SizedBox(height: 12),
                        ],
                        CapsuleControlButton(
                          icon: Icons.skip_previous_rounded,
                          onTap: widget.player.previous,
                          accent: accentTint,
                          fill: controlFill,
                        ),
                        const SizedBox(height: 10),
                        CapsuleControlButton(
                          icon: state.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          highlighted: true,
                          onTap: widget.player.toggle,
                          accent: accentTint,
                          fill: controlFill,
                        ),
                        const SizedBox(height: 10),
                        CapsuleControlButton(
                          icon: Icons.skip_next_rounded,
                          onTap: widget.player.next,
                          accent: accentTint,
                          fill: controlFill,
                        ),
                        const SizedBox(height: 12),
                        VerticalTimer(
                          positionListenable: positionNotifier,
                          durationListenable: durationNotifier,
                        ),
                        const SizedBox(height: 12),
                        CapsuleControlButton(
                          icon: expanded
                              ? Icons.keyboard_arrow_right_rounded
                              : Icons.keyboard_arrow_left_rounded,
                          onTap: () async => _setExpanded(!expanded),
                          accent: accentTint,
                          fill: controlFill,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class VerticalTimer extends StatelessWidget {
  const VerticalTimer({
    required this.positionListenable,
    required this.durationListenable,
    super.key,
  });

  final ValueListenable<Duration> positionListenable;
  final ValueListenable<Duration> durationListenable;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: CanaryTheme.text.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CanaryTheme.border),
      ),
      child: ValueListenableBuilder<Duration>(
        valueListenable: positionListenable,
        builder: (context, position, _) {
          return ValueListenableBuilder<Duration>(
            valueListenable: durationListenable,
            builder: (context, duration, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatDuration(position),
                    style: const TextStyle(
                      color: CanaryTheme.text,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Container(
                    width: 18,
                    height: 1,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    color: CanaryTheme.faint.withValues(alpha: .52),
                  ),
                  Text(
                    formatDuration(duration),
                    style: const TextStyle(
                      color: CanaryTheme.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class ExpandedPlayerWing extends StatelessWidget {
  const ExpandedPlayerWing({
    required this.width,
    required this.track,
    required this.positionListenable,
    required this.durationListenable,
    required this.volumeListenable,
    required this.onSeek,
    required this.onVolumeChanged,
    super.key,
  });

  final double width;
  final CanaryTrack? track;
  final ValueListenable<Duration> positionListenable;
  final ValueListenable<Duration> durationListenable;
  final ValueListenable<double> volumeListenable;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<double> onVolumeChanged;

  @override
  Widget build(BuildContext context) {
    final currentTrack = track;
    final coverUrl = currentTrack?.cover.sourceUrl;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: CanaryTheme.panel.withValues(alpha: .78),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: CanaryTheme.border),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (coverUrl != null && coverUrl.isNotEmpty)
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Transform.scale(
                    scale: 1.08,
                    child: CanaryImage(
                      pathOrUrl: coverUrl,
                      fit: BoxFit.cover,
                      fallback: currentTrack == null
                          ? const SizedBox.shrink()
                          : _FallbackCover(
                              track: currentTrack,
                              size: width,
                              colors: const [
                                CanaryTheme.honey,
                                CanaryTheme.canary,
                              ],
                            ),
                    ),
                  ),
                )
              else if (currentTrack != null)
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Transform.scale(
                    scale: 1.08,
                    child: _FallbackCover(
                      track: currentTrack,
                      size: width,
                      colors: const [CanaryTheme.honey, CanaryTheme.canary],
                    ),
                  ),
                ),
              Container(color: CanaryTheme.text.withValues(alpha: .24)),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: .12),
                      CanaryTheme.text.withValues(alpha: .10),
                      CanaryTheme.text.withValues(alpha: .48),
                    ],
                  ),
                ),
              ),
              if (currentTrack == null)
                const Center(
                  child: Icon(Icons.music_note_rounded, color: Colors.white),
                )
              else ...[
                Center(
                  child: Container(
                    width: 148,
                    height: 148,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: .18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .24),
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CoverTile(track: currentTrack, size: 148),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      Text(
                        currentTrack.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currentTrack.displayArtist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .78),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ExpandedPlayerControls(
                        positionListenable: positionListenable,
                        durationListenable: durationListenable,
                        volumeListenable: volumeListenable,
                        onSeek: onSeek,
                        onVolumeChanged: onVolumeChanged,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ExpandedPlayerControls extends StatelessWidget {
  const ExpandedPlayerControls({
    required this.positionListenable,
    required this.durationListenable,
    required this.volumeListenable,
    required this.onSeek,
    required this.onVolumeChanged,
    super.key,
  });

  final ValueListenable<Duration> positionListenable;
  final ValueListenable<Duration> durationListenable;
  final ValueListenable<double> volumeListenable;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<double> onVolumeChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: positionListenable,
      builder: (context, position, _) {
        return ValueListenableBuilder<Duration>(
          valueListenable: durationListenable,
          builder: (context, duration, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      formatDuration(position),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatDuration(duration),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .78),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 10,
                    ),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white.withValues(alpha: .26),
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: duration.inMilliseconds <= 0
                        ? 0
                        : position.inMilliseconds
                              .clamp(0, duration.inMilliseconds)
                              .toDouble(),
                    max: duration.inMilliseconds <= 0
                        ? 1
                        : duration.inMilliseconds.toDouble(),
                    onChanged: duration.inMilliseconds <= 0
                        ? null
                        : (value) =>
                              onSeek(Duration(milliseconds: value.round())),
                  ),
                ),
                ValueListenableBuilder<double>(
                  valueListenable: volumeListenable,
                  builder: (context, volume, _) {
                    return Row(
                      children: [
                        Icon(
                          Icons.volume_down_rounded,
                          color: Colors.white.withValues(alpha: .82),
                          size: 18,
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 10,
                              ),
                              activeTrackColor: CanaryTheme.canary,
                              inactiveTrackColor: Colors.white.withValues(
                                alpha: .24,
                              ),
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: volume.clamp(0.0, 1.0),
                              onChanged: onVolumeChanged,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.volume_up_rounded,
                          color: Colors.white.withValues(alpha: .82),
                          size: 18,
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class GlassTextCapsule extends StatelessWidget {
  const GlassTextCapsule({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .34),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: .22)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class CapsuleControlButton extends StatelessWidget {
  const CapsuleControlButton({
    required this.icon,
    required this.onTap,
    required this.accent,
    required this.fill,
    this.highlighted = false,
    super.key,
  });

  final IconData icon;
  final Future<void> Function() onTap;
  final Color accent;
  final Color fill;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => unawaited(onTap()),
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: highlighted ? accent.withValues(alpha: .92) : fill,
            border: Border.all(
              color: highlighted
                  ? Colors.white.withValues(alpha: .38)
                  : accent.withValues(alpha: .28),
            ),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: .26),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: highlighted
                ? CanaryTheme.text
                : CanaryTheme.text.withValues(alpha: .82),
            size: 28,
          ),
        ),
      ),
    );
  }
}
