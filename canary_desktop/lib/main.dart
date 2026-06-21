import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:io'
    show Directory, File, FileSystemEntity, Platform, ProcessSignal;
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'core/canary_models.dart';
import 'features/library/library_controller.dart';
import 'features/player/desktop_notification_service.dart';
import 'features/player/player_state.dart';
import 'ui/canary_theme.dart';

part 'features/dashboard/search_dashboard.dart';
part 'features/dashboard/dashboard_core.dart';
part 'features/library/library_views.dart';
part 'features/album/album_views.dart';
part 'features/player/player_widgets.dart';
part 'features/import/import_dialogs.dart';
part 'ui/sidebar.dart';
part 'ui/shared_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();
  await CanaryDesktopNotifications.setup();
  runApp(const CanaryApp());
}

class CanaryApp extends StatefulWidget {
  const CanaryApp({super.key});

  @override
  State<CanaryApp> createState() => _CanaryAppState();
}

class _CanaryAppState extends State<CanaryApp> with WindowListener {
  late final LibraryController library;
  late final CanaryPlayerState player;
  late final ValueNotifier<bool> playerExpanded;
  late final CanaryDesktopNotifications notifications;
  StreamSubscription<CanaryPlayerSnapshot>? notificationSubscription;
  StreamSubscription<ProcessSignal>? focusSignalSubscription;
  Timer? customNotificationTimer;
  CanaryTrack? notificationTrack;
  String? lastNotificationTrackId;
  bool customNotificationVisible = false;
  bool windowFocused = true;

  @override
  void initState() {
    super.initState();
    library = LibraryController()..emit();
    player = CanaryPlayerState();
    playerExpanded = ValueNotifier(false);
    notifications = CanaryDesktopNotifications(
      onOpenCanary: () => playerExpanded.value = true,
    );
    windowManager.addListener(this);
    unawaited(_syncWindowFocus());
    notificationSubscription = player.snapshots.listen((snapshot) {
      final track = snapshot.track;
      if (track != null && snapshot.isPlaying) {
        unawaited(_showNowPlaying(track));
      }
    });
    focusSignalSubscription = ProcessSignal.sigusr1.watch().listen((_) {
      unawaited(_bringCanaryToFront());
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    customNotificationTimer?.cancel();
    library.dispose();
    unawaited(notificationSubscription?.cancel());
    unawaited(focusSignalSubscription?.cancel());
    playerExpanded.dispose();
    unawaited(player.dispose());
    super.dispose();
  }

  @override
  void onWindowFocus() {
    windowFocused = true;
  }

  @override
  void onWindowBlur() {
    windowFocused = false;
  }

  Future<void> _syncWindowFocus() async {
    try {
      windowFocused = await windowManager.isFocused();
    } catch (_) {
      windowFocused = true;
    }
  }

  Future<void> _bringCanaryToFront() async {
    playerExpanded.value = true;
    try {
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {
      // Window focus is compositor-dependent.
    }
  }

  Future<void> _showNowPlaying(CanaryTrack track) async {
    if (lastNotificationTrackId == track.id) return;
    lastNotificationTrackId = track.id;

    var canShowCustom = windowFocused;
    try {
      final visible = await windowManager.isVisible();
      final minimized = await windowManager.isMinimized();
      canShowCustom = visible && !minimized;
    } catch (_) {
      canShowCustom = windowFocused;
    }

    if (canShowCustom) {
      customNotificationTimer?.cancel();
      setState(() {
        notificationTrack = track;
        customNotificationVisible = true;
      });
      customNotificationTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => customNotificationVisible = false);
      });
    } else {
      await notifications.showNowPlaying(track);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Canary',
      debugShowCheckedModeBanner: false,
      theme: CanaryTheme.light(),
      home: CanaryHome(
        library: library,
        player: player,
        playerExpanded: playerExpanded,
        notificationTrack: notificationTrack,
        notificationVisible: customNotificationVisible,
        onNotificationTap: () {
          customNotificationTimer?.cancel();
          playerExpanded.value = true;
          setState(() => customNotificationVisible = false);
        },
      ),
    );
  }
}

class CanaryHome extends StatefulWidget {
  const CanaryHome({
    required this.library,
    required this.player,
    required this.playerExpanded,
    required this.notificationTrack,
    required this.notificationVisible,
    required this.onNotificationTap,
    super.key,
  });

  final LibraryController library;
  final CanaryPlayerState player;
  final ValueNotifier<bool> playerExpanded;
  final CanaryTrack? notificationTrack;
  final bool notificationVisible;
  final VoidCallback onNotificationTap;

  @override
  State<CanaryHome> createState() => _CanaryHomeState();
}

class _CanaryHomeState extends State<CanaryHome> {
  DashboardRoute route = const DashboardRoute.home();
  int routeSerial = 0;

  void openRoute(DashboardRoute next) {
    setState(() {
      route = next;
      routeSerial++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: CanaryTheme.background),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                Row(
                  children: [
                    CanarySidebar(
                      library: widget.library,
                      route: route,
                      onRouteSelected: openRoute,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: LibraryDashboard(
                        library: widget.library,
                        player: widget.player,
                        route: route,
                        routeSerial: routeSerial,
                        onRouteChanged: openRoute,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  right: 10,
                  top: 96,
                  bottom: 96,
                  child: FloatingVerticalPlayer(
                    library: widget.library,
                    player: widget.player,
                    expandedNotifier: widget.playerExpanded,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CanaryNowPlayingToast(
                    track: widget.notificationTrack,
                    visible: widget.notificationVisible,
                    onTap: widget.onNotificationTap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
