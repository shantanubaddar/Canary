import 'dart:io';

import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/canary_models.dart';

class CanaryDesktopNotifications {
  CanaryDesktopNotifications({required this.onOpenCanary});

  final void Function() onOpenCanary;
  String? _lastTrackId;

  static Future<void> setup() async {
    try {
      await localNotifier.setup(appName: 'Canary');
    } catch (_) {
      // Some desktop/test environments do not expose a notification server.
    }
  }

  Future<void> showNowPlaying(CanaryTrack track) async {
    if (_lastTrackId == track.id) return;
    _lastTrackId = track.id;
    if (Platform.isLinux && await _showLinuxCanaryNotification(track)) return;
    try {
      final notification = LocalNotification(
        title: 'Now Playing',
        body: '${track.title}\nBy ${track.displayArtist}',
      );
      notification.onClick = () async {
        try {
          if (await windowManager.isMinimized()) {
            await windowManager.restore();
          }
          await windowManager.show();
          await windowManager.focus();
          onOpenCanary();
        } catch (_) {
          onOpenCanary();
          // Focusing is best-effort and varies by compositor/window manager.
        }
      };
      notification.show();
    } catch (_) {
      // Playback must never depend on notification availability.
    }
  }

  Future<bool> _showLinuxCanaryNotification(CanaryTrack track) async {
    final helper = _linuxHelperPath();
    if (helper == null || !await File(helper).exists()) return false;
    try {
      await Process.start(helper, [
        '--title',
        track.title,
        '--artist',
        track.displayArtist,
        '--cover',
        track.cover.sourceUrl?.replaceFirst('file://', '') ?? '',
        '--pid',
        pid.toString(),
      ], mode: ProcessStartMode.detached);
      return true;
    } catch (_) {
      return false;
    }
  }

  String? _linuxHelperPath() {
    final executable = Platform.resolvedExecutable;
    if (executable.isEmpty) return null;
    return '${File(executable).parent.path}/canary_notify';
  }
}
