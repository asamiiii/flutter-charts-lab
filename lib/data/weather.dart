import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

class City {
  final String name;
  final double latitude, longitude;
  const City(this.name, this.latitude, this.longitude);
  static const all = [
    City('Cairo', 30.0444, 31.2357),
    City('Alexandria', 31.2001, 29.9187),
    City('Riyadh', 24.7136, 46.6753),
    City('London', 51.5072, -0.1276),
  ];
}

class Reading {
  final DateTime time;
  final double temperature, humidity, wind, rain;
  const Reading(
    this.time,
    this.temperature,
    this.humidity,
    this.wind,
    this.rain,
  );
}

class WeatherData {
  final List<Reading> readings;
  final bool demo;
  final DateTime fetchedAt;
  const WeatherData(this.readings, this.demo, this.fetchedAt);

  factory WeatherData.parse(Map<String, dynamic> json) {
    final h = json['hourly'];
    if (h is! Map) throw const FormatException('Missing hourly data');
    final times = h['time'];
    if (times is! List) throw const FormatException('Missing timestamps');
    final keys = [
      'temperature_2m',
      'relative_humidity_2m',
      'wind_speed_10m',
      'precipitation',
    ];
    for (final key in keys) {
      if (h[key] is! List || (h[key] as List).length != times.length) {
        throw FormatException('Invalid series: $key');
      }
    }
    final rows = <Reading>[];
    for (var i = 0; i < times.length; i++) {
      final values = keys.map((k) => h[k][i]).toList();
      // Incomplete hours are skipped, never silently converted to zero.
      if (values.any((v) => v is! num || !v.isFinite)) continue;
      final timestamp = times[i] as String;
      rows.add(
        Reading(
          DateTime.parse(timestamp.endsWith('Z') ? timestamp : '${timestamp}Z'),
          (values[0] as num).toDouble(),
          (values[1] as num).toDouble(),
          (values[2] as num).toDouble(),
          (values[3] as num).toDouble(),
        ),
      );
    }
    if (rows.isEmpty) {
      throw const FormatException('No complete hourly readings');
    }
    rows.sort((a, b) => a.time.compareTo(b.time));
    return WeatherData(List.unmodifiable(rows), false, DateTime.now());
  }

  factory WeatherData.sample(City city) {
    final start = DateTime.utc(2026, 10, 26);
    return WeatherData(
      List.generate(168, (i) {
        final wave = math.sin((i % 24 - 8) / 24 * 2 * math.pi);
        return Reading(
          start.add(Duration(hours: i)),
          23 + city.latitude / 12 + wave * 6,
          55 - wave * 20,
          12 + math.sin(i / 8) * 6,
          i % 17 < 3 ? (i % 3 + 1) * 0.4 : 0,
        );
      }),
      true,
      DateTime.now(),
    );
  }

  List<Reading> hours(int days) {
    final end = readings.first.time.add(Duration(days: days));
    return readings.where((r) => r.time.isBefore(end)).toList();
  }
}

class WeatherApi {
  final http.Client client;
  WeatherApi(this.client);

  static Uri endpoint(City city) =>
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '${city.latitude}',
        'longitude': '${city.longitude}',
        'hourly':
            'temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation',
        'forecast_days': '7',
        'timezone': 'UTC',
        'temperature_unit': 'celsius',
        'wind_speed_unit': 'kmh',
        'precipitation_unit': 'mm',
      });

  Future<WeatherData> fetch(City city) async {
    final response =
        await client.get(endpoint(city)).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(
        'Weather service returned HTTP ${response.statusCode}. Please retry.',
      );
    }
    return WeatherData.parse(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

class DaySummary {
  final DateTime date;
  final List<Reading> rows;
  const DaySummary(this.date, this.rows);
  double get low => rows.map((r) => r.temperature).reduce(math.min);
  double get high => rows.map((r) => r.temperature).reduce(math.max);
  double get rain => rows.fold(0, (sum, r) => sum + r.rain);
}

List<DaySummary> summarize(List<Reading> rows) {
  final groups = <DateTime, List<Reading>>{};
  for (final r in rows) {
    final key = DateTime.utc(r.time.year, r.time.month, r.time.day);
    (groups[key] ??= []).add(r);
  }
  return groups.entries.map((e) => DaySummary(e.key, e.value)).toList();
}

List<int> temperatureBuckets(List<Reading> rows) => [
      rows.where((r) => r.temperature < 20).length,
      rows.where((r) => r.temperature >= 20 && r.temperature < 30).length,
      rows.where((r) => r.temperature >= 30).length,
    ];
