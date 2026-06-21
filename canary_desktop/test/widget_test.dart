import 'dart:ui' show Size;

import 'package:canary_desktop/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  setUpAll(MediaKit.ensureInitialized);

  testWidgets('Canary desktop shell renders', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const CanaryApp());
    await tester.pumpAndSettle();
    expect(find.text('Canary'), findsOneWidget);
    expect(find.text('Desktop Library'), findsOneWidget);
    expect(find.text('Song Lookup'), findsOneWidget);
  });
}
