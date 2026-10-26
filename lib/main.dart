import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'data/weather.dart';
import 'ui/charts.dart';

void main() => runApp(const ChartsLab());

class ChartsLab extends StatefulWidget {
  final WeatherApi? api;
  final bool startInDemo;
  const ChartsLab({super.key, this.api, this.startInDemo = false});
  @override
  State<ChartsLab> createState() => _ChartsLabState();
}

class _ChartsLabState extends State<ChartsLab> {
  bool dark = true;
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flutter Charts Lab',
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: Dashboard(
          api: widget.api,
          startInDemo: widget.startInDemo,
          dark: dark,
          toggleTheme: () => setState(() => dark = !dark),
        ),
      );

  ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette[0],
        brightness: brightness,
      ),
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF10121C) : const Color(0xFFF5F6FB),
      fontFamily: 'sans-serif',
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF191C2A) : Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: isDark ? const Color(0xFF292D40) : const Color(0xFFE5E7F0),
          ),
        ),
      ),
    );
  }
}

class Dashboard extends StatefulWidget {
  final WeatherApi? api;
  final bool startInDemo, dark;
  final VoidCallback toggleTheme;
  const Dashboard({
    super.key,
    this.api,
    required this.startInDemo,
    required this.dark,
    required this.toggleTheme,
  });
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late final http.Client _client;
  late final WeatherApi _api;
  City _city = City.all.first;
  WeatherData? _data;
  bool _loading = false, _demo = false;
  String? _error;
  int _days = 7, _selected = -1, _generation = 0;

  @override
  void initState() {
    super.initState();
    _client = http.Client();
    _api = widget.api ?? WeatherApi(_client);
    _demo = widget.startInDemo;
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final result =
          _demo ? WeatherData.sample(_city) : await _api.fetch(_city);
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = e is TimeoutException
            ? 'The request timed out. Check your connection and retry.'
            : 'Could not load the forecast. Check your connection or try Demo mode.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _data?.hours(_days);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1420),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _header(),
                          const SizedBox(height: 32),
                          Text(
                            'REAL DATA. DIFFERENT PERSPECTIVES.',
                            style: TextStyle(
                              color: palette[1],
                              fontSize: 11,
                              letterSpacing: 2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Make the numbers\ntell a story.',
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                  letterSpacing: -1.5,
                                ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'One Flutter codebase. Ten chart styles. Explore a real weather forecast from API to pixels.',
                            style: TextStyle(color: Colors.grey, height: 1.7),
                          ),
                          const SizedBox(height: 26),
                          _controls(),
                          const SizedBox(height: 20),
                          _source(),
                          if (rows != null) ...[
                            const SizedBox(height: 24),
                            _metrics(rows),
                          ],
                          const SizedBox(height: 30),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('All charts'),
                                selected: _selected == -1,
                                onSelected: (_) =>
                                    setState(() => _selected = -1),
                              ),
                              for (var i = 0; i < chartNames.length; i++)
                                ChoiceChip(
                                  label: Text(chartNames[i]),
                                  selected: _selected == i,
                                  onSelected: (_) =>
                                      setState(() => _selected = i),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (_loading)
                            const Padding(
                              padding: EdgeInsets.all(64),
                              child: Center(
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 18),
                                    Text('Fetching forecast from Open-Meteo…'),
                                  ],
                                ),
                              ),
                            ),
                          if (_error != null)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.cloud_off_rounded,
                                      size: 40,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(_error!, textAlign: TextAlign.center),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 12,
                                      children: [
                                        FilledButton.icon(
                                          onPressed: _load,
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Retry'),
                                        ),
                                        OutlinedButton(
                                          onPressed: () {
                                            _demo = true;
                                            _load();
                                          },
                                          child: const Text('Try demo data'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (rows != null)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth >= 850 &&
                                        _selected == -1
                                    ? 2
                                    : 1;
                                final width = (constraints.maxWidth -
                                        20 * (columns - 1)) /
                                    columns;
                                final kinds = _selected == -1
                                    ? List.generate(chartNames.length, (i) => i)
                                    : [_selected];
                                return Wrap(
                                  spacing: 20,
                                  runSpacing: 20,
                                  children: [
                                    for (final i in kinds)
                                      SizedBox(
                                        width: width,
                                        height: 420,
                                        child: _chartCard(i, rows),
                                      ),
                                  ],
                                );
                              },
                            ),
                          const SizedBox(height: 32),
                          Wrap(
                            spacing: 16,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Built with Flutter + fl_chart',
                                style: TextStyle(color: Colors.grey),
                              ),
                              TextButton.icon(
                                onPressed: _about,
                                icon: const Icon(Icons.info_outline, size: 16),
                                label: const Text('About this showcase'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette[0],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.stacked_line_chart_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHARTS LAB',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 2),
                ),
                const Text(
                  'A Flutter capability showcase',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip:
                widget.dark ? 'Switch to light theme' : 'Switch to dark theme',
            onPressed: widget.toggleTheme,
            icon: Icon(
              widget.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
        ],
      );

  Widget _controls() => Wrap(
        spacing: 16,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 185,
            child: DropdownButtonFormField<City>(
              isExpanded: true,
              initialValue: _city,
              decoration: const InputDecoration(
                labelText: 'City',
                border: OutlineInputBorder(),
              ),
              items: City.all
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                  .toList(),
              onChanged: (c) {
                if (c != null) {
                  _city = c;
                  _load();
                }
              },
            ),
          ),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('24 hours')),
              ButtonSegment(value: 3, label: Text('3 days')),
              ButtonSegment(value: 7, label: Text('7 days')),
            ],
            selected: {_days},
            onSelectionChanged: (v) => setState(() => _days = v.first),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: _demo,
                onChanged: (v) {
                  _demo = v;
                  _load();
                },
              ),
              const Text('Demo mode'),
            ],
          ),
          OutlinedButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
          ),
          OutlinedButton.icon(
            onPressed: _data == null ? null : _table,
            icon: const Icon(Icons.table_chart_outlined, size: 18),
            label: const Text('View data'),
          ),
        ],
      );

  Widget _source() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (_demo ? palette[2] : palette[1]).withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(
              _demo ? Icons.science_outlined : Icons.cloud_done_outlined,
              size: 18,
              color: _demo ? palette[2] : palette[1],
            ),
            Text(
              _demo
                  ? 'SYNTHETIC DEMO · not real weather'
                  : 'OPEN-METEO API · model forecast, not sensor measurements',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            if (_data != null)
              Text(
                '${_data!.readings.length} hourly readings · All times UTC · fetched ${_data!.fetchedAt.toUtc().toIso8601String().substring(11, 19)} UTC',
                style: const TextStyle(fontSize: 11),
              ),
          ],
        ),
      );

  Widget _metrics(List<Reading> rows) {
    final avg = rows.fold<double>(0, (s, r) => s + r.temperature) / rows.length;
    final wind = rows.fold<double>(0, (s, r) => s + r.wind) / rows.length;
    final rain = rows.fold<double>(0, (s, r) => s + r.rain);
    final items = [
      ('MEAN TEMPERATURE', '${avg.toStringAsFixed(1)}°', Icons.thermostat),
      ('MEAN WIND SPEED', '${wind.toStringAsFixed(1)} km/h', Icons.air),
      (
        'TOTAL PRECIPITATION',
        '${rain.toStringAsFixed(1)} mm',
        Icons.water_drop_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) => Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          for (final item in items)
            SizedBox(
              width:
                  box.maxWidth >= 700 ? (box.maxWidth - 32) / 3 : box.maxWidth,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$1,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item.$2,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      Icon(item.$3, color: palette[0]),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chartCard(int kind, List<Reading> rows) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${kind + 1}'.padLeft(2, '0'),
                    style: TextStyle(
                      color: palette[1],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      chartNames[kind],
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Expand ${chartNames[kind]} chart',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => Dialog(
                        child: SizedBox(
                          width: 1100,
                          height: 650,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${chartNames[kind]} · ${_city.name}',
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Close chart',
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(Icons.close),
                                    ),
                                  ],
                                ),
                                Text(chartDescriptions[kind]),
                                const SizedBox(height: 24),
                                Expanded(
                                  child: ChartView(kind: kind, rows: rows),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_full, size: 18),
                  ),
                ],
              ),
              Text(
                chartDescriptions[kind],
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ChartView(
                  key: ValueKey('$kind-${_city.name}-$_days-$_demo'),
                  kind: kind,
                  rows: rows,
                ),
              ),
            ],
          ),
        ),
      );

  void _table() {
    final rows = _data!.hours(_days);
    final csv =
        'Time (UTC),Temperature (C),Humidity (%),Wind (km/h),Precipitation (mm)\n${rows.map((r) => '${r.time.toIso8601String()},${r.temperature},${r.humidity},${r.wind},${r.rain}').join('\n')}';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${_city.name} · hourly data${_demo ? ' · SYNTHETIC' : ''}',
        ),
        content: SizedBox(
          width: 900,
          height: 440,
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  for (final label in [
                    'UTC',
                    '°C',
                    'Humidity %',
                    'Wind km/h',
                    'Rain mm',
                  ])
                    DataColumn(label: Text(label)),
                ],
                rows: rows
                    .map(
                      (r) => DataRow(
                        cells: [
                          DataCell(Text(hourLabel(r.time))),
                          for (final v in [
                            r.temperature,
                            r.humidity,
                            r.wind,
                            r.rain,
                          ])
                            DataCell(Text(v.toStringAsFixed(1))),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: csv));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV copied to clipboard')),
                );
              }
            },
            child: const Text('Copy CSV'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _about() => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('From API to pixels'),
          content: const SingleChildScrollView(
            child: SelectableText(
              'HTTP JSON → validated hourly readings → aggregations → Flutter charts.\n\n'
              'The chart widgets consume typed Reading objects. Replace WeatherApi with your business API to reuse the presentation layer.\n\n'
              'Real data: Open-Meteo numerical weather model forecasts, refreshed on demand. No automatic live stream. All timestamps use UTC.\n\n'
              'Demo mode uses deterministic synthetic data and is always labeled. Failed requests never silently fall back to demo data.\n\n'
              'Data attribution: Open-Meteo (https://open-meteo.com/), CC BY 4.0. Free endpoint for evaluation/prototyping; check provider terms before commercial deployment.\n\n'
              'Charts: fl_chart (MIT). Heatmap: Flutter widgets. Gauge: Flutter CircularProgressIndicator.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
}
