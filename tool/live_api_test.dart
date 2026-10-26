// Optional network smoke test; kept outside the deterministic test suite.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_charts_lab/data/weather.dart';

void main() {
  test('Open-Meteo real endpoint parses seven forecast days', () async {
    final client = http.Client();
    addTearDown(client.close);
    final data = await WeatherApi(client).fetch(City.all.first);
    expect(data.demo, false);
    expect(data.readings.length, 168);
    expect(data.readings.first.time.isUtc, true);
    expect(summarize(data.readings).length, 7);
  });
}
