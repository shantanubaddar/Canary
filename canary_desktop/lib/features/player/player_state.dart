import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart';

import '../../core/canary_models.dart';

class CanaryPlayerState {
  CanaryPlayerState() {
    _subscriptions = [
      _player.stream.playing.listen((playing) {
        _emit(_snapshot.copyWith(isPlaying: playing));
      }),
      _player.stream.position.listen((position) {
        _emit(_snapshot.copyWith(position: position));
      }),
      _player.stream.duration.listen((duration) {
        _emit(_snapshot.copyWith(duration: duration));
      }),
      _player.stream.volume.listen((volume) {
        _emit(_snapshot.copyWith(volume: volume / 100));
      }),
      _player.stream.completed.listen((completed) {
        if (completed) unawaited(_handleCompleted());
      }),
    ];
  }

  final Player _player = Player();
  late final List<StreamSubscription<dynamic>> _subscriptions;
  final _controller = StreamController<CanaryPlayerSnapshot>.broadcast();
  CanaryPlayerSnapshot _snapshot = CanaryPlayerSnapshot.idle();
  List<CanaryTrack> _queue = const [];
  int _queueIndex = -1;

  Stream<CanaryPlayerSnapshot> get snapshots => _controller.stream;
  CanaryPlayerSnapshot get current => _snapshot;

  Future<bool> load(CanaryTrack track, {List<CanaryTrack>? queue}) async {
    final path = track.localPath;
    if (path == null || path.isEmpty || !File(path).existsSync()) {
      _emit(_snapshot.copyWith(track: track, isPlaying: false, position: Duration.zero, duration: track.duration));
      return false;
    }

    if (queue != null && queue.isNotEmpty) {
      _queue = queue;
      _queueIndex = queue.indexWhere((item) => item.id == track.id);
    } else if (_queue.isEmpty) {
      _queue = [track];
      _queueIndex = 0;
    }

    _emit(CanaryPlayerSnapshot(track: track, isPlaying: true, position: Duration.zero, duration: track.duration, volume: _snapshot.volume));
    await _player.open(Media(Uri.file(path).toString()), play: true);
    return true;
  }

  Future<void> toggle() async {
    if (_snapshot.track == null) return;
    await _player.playOrPause();
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setVolume(double value) async {
    final next = value.clamp(0.0, 1.0);
    _emit(_snapshot.copyWith(volume: next));
    await _player.setVolume(next * 100);
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    final nextIndex = (_queueIndex + 1).clamp(0, _queue.length - 1);
    if (nextIndex == _queueIndex) return;
    _queueIndex = nextIndex;
    await load(_queue[_queueIndex], queue: _queue);
  }

  Future<void> _handleCompleted() async {
    if (_queue.isNotEmpty && _queueIndex < _queue.length - 1) {
      await next();
      return;
    }
    _emit(_snapshot.copyWith(isPlaying: false, position: Duration.zero));
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_snapshot.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    final previousIndex = (_queueIndex - 1).clamp(0, _queue.length - 1);
    if (previousIndex == _queueIndex) return;
    _queueIndex = previousIndex;
    await load(_queue[_queueIndex], queue: _queue);
  }

  Future<void> stop() async {
    await _player.stop();
    _emit(_snapshot.copyWith(isPlaying: false, position: Duration.zero));
  }

  Future<void> dispose() async {
    await stop();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _controller.close();
  }

  void _emit(CanaryPlayerSnapshot snapshot) {
    _snapshot = snapshot;
    if (!_controller.isClosed) _controller.add(snapshot);
  }
}

class CanaryPlayerSnapshot {
  const CanaryPlayerSnapshot({
    required this.track,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.volume,
  });

  factory CanaryPlayerSnapshot.idle() => const CanaryPlayerSnapshot(
    track: null,
    isPlaying: false,
    position: Duration.zero,
    duration: Duration.zero,
    volume: .82,
  );

  final CanaryTrack? track;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double volume;

  CanaryPlayerSnapshot copyWith({
    CanaryTrack? track,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? volume,
  }) {
    return CanaryPlayerSnapshot(
      track: track ?? this.track,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
    );
  }
}
