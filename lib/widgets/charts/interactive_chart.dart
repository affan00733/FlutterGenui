import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// The display style for an [InteractiveChart] — a generic UI choice the user
/// changes with the on-widget toggle, not by asking the model.
enum ChartType { area, line, bar }

/// A polished, animated chart (fl_chart) supporting area / line / bar styles
/// with built-in touch tooltips. Same public API as before so instruments are
/// unchanged.
class InteractiveChart extends StatelessWidget {
  const InteractiveChart({
    required this.values,
    this.type = ChartType.area,
    this.height = 180,
    this.labelBuilder,
    super.key,
  });

  /// Y values in order (baseline is 0).
  final List<double> values;
  final ChartType type;
  final double height;

  /// Builds the tooltip text for a touched point.
  final String Function(int index, double value)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: type == ChartType.bar ? _bar(scheme) : _line(scheme),
    );
  }

  Widget _line(ColorScheme scheme) {
    final isArea = type == ChartType.area;
    return LineChart(
      duration: const Duration(milliseconds: 280),
      LineChartData(
        minY: 0,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItems: (spots) => spots
                .map(
                  (s) => LineTooltipItem(
                    labelBuilder?.call(s.spotIndex, s.y) ??
                        s.y.toStringAsFixed(0),
                    TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < values.length; i++)
                FlSpot(i.toDouble(), values[i]),
            ],
            isCurved: true,
            color: scheme.primary,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: isArea,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.primary.withValues(alpha: 0.30),
                  scheme.primary.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(ColorScheme scheme) {
    return BarChart(
      duration: const Duration(milliseconds: 280),
      BarChartData(
        minY: 0,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
                  labelBuilder?.call(group.x, rod.toY) ??
                      rod.toY.toStringAsFixed(0),
                  TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: scheme.primary,
                  width: 8,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
