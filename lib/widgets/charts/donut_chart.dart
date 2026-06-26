import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A segment of a [DonutChart].
typedef DonutSegment = ({String label, double value, Color color});

/// An animated donut/ring chart (fl_chart) — used to show an asset allocation
/// (stocks / bonds / cash) or a budget split.
class DonutChart extends StatelessWidget {
  const DonutChart({
    required this.segments,
    this.size = 132,
    this.thickness = 26,
    super.key,
  });

  final List<DonutSegment> segments;
  final double size;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: PieChart(
        duration: const Duration(milliseconds: 280),
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: (size / 2) - thickness,
          startDegreeOffset: -90,
          sections: [
            for (final segment in segments)
              PieChartSectionData(
                value: segment.value,
                color: segment.color,
                radius: thickness,
                showTitle: false,
              ),
          ],
        ),
      ),
    );
  }
}
