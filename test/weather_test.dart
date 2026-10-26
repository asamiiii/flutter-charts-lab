import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_charts_lab/data/weather.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> fixture() => {
      'hourly': <String, dynamic>{
        'time': ['2026-10-26T23:00', '2026-10-27T00:00', '2026-10-27T01:00'],
        'temperature_2m': [19, 20, 30],
        'relative_humidity_2m': [40, 50, 60],
        'wind_speed_10m': [10, 20, 30],
        'precipitation': [0, 1.5, 2.0],
      },
    };

void main() {
  test(
    'API request has city, explicit units, UTC and seven forecast days',
    () async {
      final api = WeatherApi(
        MockClient((request) async {
          expect(request.url.host, 'api.open-meteo.com');
          expect(request.url.queryParameters['latitude'], '30.0444');
          expect(request.url.queryParameters['timezone'], 'UTC');
          expect(request.url.queryParameters['forecast_days'], '7');
          expect(request.url.queryParameters['wind_speed_unit'], 'kmh');
          return http.Response(jsonEncode(fixture()), 200);
        }),
      );
      final result = await api.fetch(City.all.first);
      expect(result.demo, false);
      expect(result.readings.length, 3);
    },
  );

  test(
    'UTC day grouping preserves rainfall totals and temperature extrema',
    () {
      final data = WeatherData.parse(fixture());
      final days = summarize(data.readings);
      expect(days.length, 2);
      expect(days.last.low, 20);
      expect(days.last.high, 30);
      expect(days.last.rain, 3.5);
      expect(temperatureBuckets(data.readings), [1, 1, 1]);
      expect(
        temperatureBuckets(data.readings).reduce((a, b) => a + b),
        data.readings.length,
      );
    },
  );

  test('missing values are excluded rather than fabricated as zero', () {
    final json = fixture();
    (json['hourly'] as Map)['temperature_2m'] = [null, 20, 30];
    expect(WeatherData.parse(json).readings.length, 2);
  });

  test('mismatched columns and empty data produce a useful parse failure', () {
    final json = fixture();
    (json['hourly'] as Map)['precipitation'] = [0];
    expect(() => WeatherData.parse(json), throwsFormatException);
    expect(
      () => WeatherData.parse({
        'hourly': <String, dynamic>{'time': []},
      }),
      throwsFormatException,
    );
  });

  test('HTTP failures do not masquerade as a successful forecast', () async {
    final api = WeatherApi(
      MockClient((_) async => http.Response('Rate limited', 429)),
    );
    await expectLater(api.fetch(City.all.first), throwsException);
  });

  test('range selection and demo data remain deterministic', () {
    final data = WeatherData.sample(City.all.first);
    expect(data.demo, true);
    expect(data.hours(1).length, 24);
    expect(data.hours(3).length, 72);
    expect(data.hours(7).length, 168);
    expect(
      data.readings.first.temperature,
      WeatherData.sample(City.all.first).readings.first.temperature,
    );
  });
}
