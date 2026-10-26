// Optional rendering utility: flutter test tool/capture_test.dart
// Set CAPTURE_FONT to a local .ttf if the default test font is unsuitable.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_charts_lab/main.dart';

void main() {
  testWidgets('capture real Flutter dashboard', (tester) async {
    final fontPath = Platform.environment['CAPTURE_FONT'];
    if (fontPath != null) {
      final loader = FontLoader('sans-serif')
        ..addFont(
          Future.value(ByteData.sublistView(File(fontPath).readAsBytesSync())),
        );
      await tester.runAsync(loader.load);
    }
    final iconPath = Platform.environment['CAPTURE_ICONS'];
    if (iconPath != null) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(Future.value(
            ByteData.sublistView(File(iconPath).readAsBytesSync())));
      await tester.runAsync(icons.load);
    }
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: key, child: const ChartsLab(startInDemo: true)),
    );
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(ChartsLab), matchesGoldenFile('../docs/dashboard.png'));
    expect(tester.takeException(), isNull);
  });
}
