import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_charts_lab/main.dart';
import 'package:flutter_charts_lab/data/weather.dart';
import 'package:flutter_charts_lab/ui/charts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'weather_test.dart' show fixture;

void main() {
  for (var kind = 0; kind < chartNames.length; kind++) {
    testWidgets(
      '${chartNames[kind]} renders all-equal, zero-rain and negative-temperature data',
      (tester) async {
        final rows = List.generate(
          24,
          (i) => Reading(DateTime.utc(2026, 10, 26, i), -4, 50, 0, 0),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 340,
                child: ChartView(kind: kind, rows: rows),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('mobile dashboard switches theme and period without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ChartsLab(startInDemo: true));
    await tester.pumpAndSettle();
    expect(find.text('SYNTHETIC DEMO · not real weather'), findsOneWidget);
    await tester.tap(find.byTooltip('Switch to light theme'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('24 hours'));
    await tester.tap(find.text('24 hours'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed API offers explicit retry and demo choice', (
    tester,
  ) async {
    final api = WeatherApi(
      MockClient((_) async => http.Response('unavailable', 503)),
    );
    await tester.pumpWidget(ChartsLab(api: api));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Try demo data'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Try demo data'));
    await tester.pumpAndSettle();
    expect(find.text('SYNTHETIC DEMO · not real weather'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('out-of-order responses cannot overwrite the selected city', (
    tester,
  ) async {
    final requests = <Completer<http.Response>>[];
    final api = WeatherApi(
      MockClient((_) {
        final c = Completer<http.Response>();
        requests.add(c);
        return c.future;
      }),
    );
    await tester.pumpWidget(ChartsLab(api: api));
    await tester.pump();
    await tester.tap(find.byType(DropdownButtonFormField<City>));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('London').last);
    await tester.pump();
    requests.last.complete(http.Response(jsonEncode(fixture()), 200));
    await tester.pumpAndSettle();
    requests.first.complete(http.Response('old failure', 500));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load the forecast'), findsNothing);
    expect(find.text('London'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
