import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/weather.dart';

const palette = [Color(0xFF7166F9), Color(0xFF26C6AA), Color(0xFFFFB454)];
const chartNames = [
  'Line',
  'Area',
  'Bar',
  'Stacked bar',
  'Pie',
  'Donut',
  'Scatter',
  'Radar',
  'Heatmap',
  'Gauge',
];
const chartDescriptions = [
  'Hourly temperature · °C · tap or hover for values',
  'Hourly wind speed · km/h · filled time series',
  'Daily temperature range · grouped minimum / maximum · °C',
  'Hours per day in temperature bands · counts, not °C',
  'Share of hours in each temperature band',
  'Same distribution with a center label',
  'Temperature (x, °C) against humidity (y, %) · one dot per hour',
  'Mean humidity at 00, 06, 12, 18 UTC · % on every axis',
  'Hourly temperature by day · scroll horizontally · tap a cell',
  'Mean relative humidity · fixed scale 0–100%',
];
String dateLabel(DateTime d) => '${d.day}/${d.month}';
String hourLabel(DateTime d) =>
    '${dateLabel(d)} ${d.hour.toString().padLeft(2, '0')}:00';

class ChartView extends StatelessWidget {
  final int kind;
  final List<Reading> rows;
  const ChartView({super.key, required this.kind, required this.rows});

  FlTitlesData get hiddenTitles => const FlTitlesData(show: false);
  FlBorderData get border => FlBorderData(show: false);
  FlGridData get grid => FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            const FlLine(color: Color(0x22888899), strokeWidth: 1),
      );
  Widget axis(String value) =>
      Text(value, style: const TextStyle(fontSize: 10));
  FlTitlesData titles({bool days = false}) {
    final daily = summarize(rows);
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 38,
          minIncluded: false,
          maxIncluded: false,
          getTitlesWidget: (v, _) => axis(v.toStringAsFixed(0)),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          interval:
              days ? 1 : math.max(1, (rows.length / 4).floor()).toDouble(),
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (days) {
              return i >= 0 && i < daily.length
                  ? axis(dateLabel(daily[i].date))
                  : const SizedBox.shrink();
            }
            if (i < 0 || i >= rows.length) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: axis(
                '${dateLabel(rows[i].time)}\n${rows[i].time.hour}:00',
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case 0:
      case 1:
        final wind = kind == 1;
        return LineChart(
          LineChartData(
            minX: 0,
            maxX: math.max(1, rows.length - 1).toDouble(),
            titlesData: titles(),
            borderData: border,
            gridData: grid,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots
                    .map(
                      (s) => LineTooltipItem(
                        '${hourLabel(rows[s.x.toInt()].time)} UTC\n${s.y.toStringAsFixed(1)} ${wind ? 'km/h' : '°C'}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < rows.length; i++)
                    FlSpot(
                      i.toDouble(),
                      wind ? rows[i].wind : rows[i].temperature,
                    ),
                ],
                color: wind ? palette[1] : palette[0],
                barWidth: 3,
                isCurved: false,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: wind,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette[1].withValues(alpha: .38),
                      palette[1].withValues(alpha: .01),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      case 2:
      case 3:
        final daily = summarize(rows);
        final stacked = kind == 3;
        return Column(
          children: [
            Wrap(
              spacing: 12,
              children: stacked
                  ? [
                      for (var i = 0; i < 3; i++)
                        Legend(['<20°C', '20–<30°C', '≥30°C'][i], palette[i]),
                    ]
                  : [
                      Legend('Min °C', palette[1]),
                      Legend('Max °C', palette[0]),
                    ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: BarChart(
                BarChartData(
                  minY: stacked
                      ? 0
                      : math.min(
                          0,
                          daily.map((d) => d.low).reduce(math.min) - 2,
                        ),
                  titlesData: titles(days: true),
                  borderData: border,
                  gridData: grid,
                  barGroups: [
                    for (var i = 0; i < daily.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: stacked
                            ? [
                                BarChartRodData(
                                  toY: daily[i].rows.length.toDouble(),
                                  width: 24,
                                  borderRadius: BorderRadius.circular(4),
                                  rodStackItems: _stacks(
                                    temperatureBuckets(daily[i].rows),
                                  ),
                                ),
                              ]
                            : [
                                BarChartRodData(
                                  toY: daily[i].low,
                                  width: 10,
                                  color: palette[1],
                                ),
                                BarChartRodData(
                                  toY: daily[i].high,
                                  width: 10,
                                  color: palette[0],
                                ),
                              ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      case 4:
      case 5:
        final counts = temperatureBuckets(rows);
        return Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      centerSpaceRadius: kind == 5 ? 62 : 0,
                      sectionsSpace: 4,
                      sections: [
                        for (var i = 0; i < 3; i++)
                          if (counts[i] > 0)
                            PieChartSectionData(
                              value: counts[i].toDouble(),
                              color: palette[i],
                              radius: kind == 5 ? 38 : 96,
                              title:
                                  '${(counts[i] / rows.length * 100).round()}%',
                              titleStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                      ],
                    ),
                  ),
                  if (kind == 5)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${rows.length}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const Text('hours'),
                      ],
                    ),
                ],
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (var i = 0; i < 3; i++)
                  Legend(
                    '${['<20°C', '20–<30°C', '≥30°C'][i]} · ${counts[i]}h',
                    palette[i],
                  ),
              ],
            ),
          ],
        );
      case 6:
        return ScatterChart(
          ScatterChartData(
            minX: rows.map((r) => r.temperature).reduce(math.min) - 2,
            maxX: rows.map((r) => r.temperature).reduce(math.max) + 2,
            minY: 0,
            maxY: 100,
            borderData: border,
            gridData: grid,
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: const AxisTitles(
                axisNameWidget: Text('Temperature · °C'),
                sideTitles: SideTitles(showTitles: true, reservedSize: 24),
              ),
              leftTitles: const AxisTitles(
                axisNameWidget: Text('Humidity · %'),
                sideTitles: SideTitles(showTitles: true, reservedSize: 30),
              ),
            ),
            scatterSpots: [
              for (final r in rows)
                ScatterSpot(
                  r.temperature,
                  r.humidity,
                  dotPainter: FlDotCirclePainter(
                    radius: 4,
                    color: palette[0].withValues(alpha: .6),
                    strokeWidth: 0,
                  ),
                ),
            ],
          ),
        );
      case 7:
        final values = [0, 6, 12, 18].map((h) {
          final matching = rows.where((r) => r.time.hour == h).toList();
          return matching.isEmpty
              ? 0.0
              : matching.fold<double>(0, (s, r) => s + r.humidity) /
                  matching.length;
        }).toList();
        // A transparent reference polygon fixes the radar's outer scale at 100%.
        return RadarChart(
          RadarChartData(
            radarShape: RadarShape.polygon,
            tickCount: 4,
            ticksTextStyle: const TextStyle(fontSize: 10, color: Colors.grey),
            getTitle: (i, angle) =>
                RadarChartTitle(text: '${[0, 6, 12, 18][i]}:00 UTC', angle: 0),
            titleTextStyle: Theme.of(context).textTheme.labelSmall,
            radarBorderData: const BorderSide(color: Color(0x44888899)),
            gridBorderData: const BorderSide(color: Color(0x22888899)),
            tickBorderData: const BorderSide(color: Color(0x22888899)),
            dataSets: [
              RadarDataSet(
                dataEntries: List.generate(
                  4,
                  (_) => const RadarEntry(value: 100),
                ),
                fillColor: Colors.transparent,
                borderColor: Colors.transparent,
                entryRadius: 0,
              ),
              RadarDataSet(
                dataEntries: values.map((v) => RadarEntry(value: v)).toList(),
                fillColor: palette[0].withValues(alpha: .22),
                borderColor: palette[0],
                entryRadius: 4,
              ),
            ],
          ),
        );
      case 8:
        return _heatmap(context);
      default:
        final mean =
            rows.fold<double>(0, (s, r) => s + r.humidity) / rows.length;
        return Center(
          child: SizedBox(
            width: 215,
            height: 215,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: mean / 100,
                    strokeWidth: 20,
                    backgroundColor: palette[0].withValues(alpha: .12),
                    color: palette[1],
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${mean.round()}%',
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Text('Mean humidity'),
                    const Text('0–100%', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        );
    }
  }

  List<BarChartRodStackItem> _stacks(List<int> counts) {
    var start = 0.0;
    return List.generate(3, (i) {
      final end = start + counts[i];
      final item = BarChartRodStackItem(start, end, palette[i]);
      start = end;
      return item;
    });
  }

  Widget _heatmap(BuildContext context) {
    final days = summarize(rows);
    final low = rows.map((r) => r.temperature).reduce(math.min);
    final high = rows.map((r) => r.temperature).reduce(math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 728,
              child: SingleChildScrollView(
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 56),
                      for (var h = 0; h < 24; h++)
                        SizedBox(
                          width: 28,
                          child: Text(
                            '$h',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 9),
                          ),
                        ),
                    ],
                  ),
                  for (final day in days)
                    Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text(
                            dateLabel(day.date),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        for (var h = 0; h < 24; h++)
                          _heatCell(context, day, h, low, high),
                      ],
                    ),
                ],
              )),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Legend('${low.toStringAsFixed(1)}°C', palette[1]),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: LinearGradient(
                    colors: [palette[1], palette[0], palette[2]],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Legend('${high.toStringAsFixed(1)}°C', palette[2]),
          ],
        ),
      ],
    );
  }

  Widget _heatCell(
    BuildContext context,
    DaySummary day,
    int hour,
    double low,
    double high,
  ) {
    final matching = day.rows.where((r) => r.time.hour == hour);
    final r = matching.isEmpty ? null : matching.first;
    final fraction = r == null
        ? 0.0
        : ((r.temperature - low) / math.max(.01, high - low)).clamp(0.0, 1.0);
    final label = r == null
        ? 'No data'
        : '${hourLabel(r.time)} UTC · ${r.temperature.toStringAsFixed(1)}°C';
    final color = r == null
        ? Colors.grey.withValues(alpha: .15)
        : fraction < .5
            ? Color.lerp(palette[1], palette[0], fraction * 2)!
            : Color.lerp(palette[0], palette[2], (fraction - .5) * 2)!;
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: InkWell(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(label),
              duration: const Duration(seconds: 2),
            ),
          ),
          child: Container(
            width: 24,
            height: 23,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

class Legend extends StatelessWidget {
  final String label;
  final Color color;
  const Legend(this.label, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}
