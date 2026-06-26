import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/format.dart';
import 'package:genui_template/tones.dart';
import 'package:genui_template/widgets/apply_action_button.dart';
import 'package:genui_template/widgets/charts/interactive_chart.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// GrowthProjection — an interactive "what will this grow to?" chart.
///
/// The model parameterizes the starting amount, monthly contribution, return
/// and horizon; the user drags the return slider and the area chart, end
/// balance, and growth breakdown recompute live in Flutter.
final growthProjection = CatalogItem(
  name: 'GrowthProjection',
  dataSchema: S.object(
    description:
        'An interactive projection chart for how money grows over time. Use '
        'when the user asks what an amount could become, or to visualize '
        'compounding. The user drags a return slider; the chart updates live.',
    properties: {
      'title': S.string(description: 'Short heading for the projection.'),
      'principal': S.number(description: 'Starting amount in dollars.'),
      'monthlyContribution': S.number(
        description: 'Recurring monthly contribution in dollars (0 if none).',
      ),
      'annualRatePct': S.number(
        description: 'Starting assumed annual return as a percent (1-12).',
      ),
      'years': S.integer(description: 'Projection horizon in years (1-40).'),
      'tone': S.string(
        description: 'Palette that fits the topic (growth leans emerald/teal).',
        enumValues: InstrumentTone.names,
      ),
    },
    required: ['principal', 'annualRatePct', 'years'],
  ),
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "GrowthProjection",
          "title": "Investing your bonus for 20 years",
          "principal": 10000,
          "monthlyContribution": 300,
          "annualRatePct": 7,
          "years": 20,
          "tone": "emerald"
        }
      ]
    ''',
    () => r'''
      [
        {
          "id": "root",
          "component": "GrowthProjection",
          "title": "Just $500 a month, for 30 years",
          "principal": 0,
          "monthlyContribution": 500,
          "annualRatePct": 7,
          "years": 30
        }
      ]
    ''',
  ],
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    num readNum(String key, num fallback) => (data[key] as num?) ?? fallback;

    return Toned(
      tone: InstrumentTone.fromName(data['tone'] as String?),
      child: _GrowthProjectionView(
        title: (data['title'] as String?) ?? 'Growth projection',
        principal: readNum('principal', 0).toDouble(),
        monthly: readNum('monthlyContribution', 0).toDouble(),
        initialRate: readNum('annualRatePct', 7).toDouble().clamp(1, 12),
        years: readNum('years', 10).toInt().clamp(1, 40),
        onApply: (summary) => itemContext.dispatchEvent(
          UserActionEvent(
            name: 'startInvestingPlan',
            sourceComponentId: itemContext.id,
            context: {'summary': summary},
          ),
        ),
      ),
    );
  },
);

class _GrowthProjectionView extends StatefulWidget {
  const _GrowthProjectionView({
    required this.title,
    required this.principal,
    required this.monthly,
    required this.initialRate,
    required this.years,
    required this.onApply,
  });

  final String title;
  final double principal;
  final double monthly;
  final double initialRate;
  final int years;
  final void Function(String summary) onApply;

  @override
  State<_GrowthProjectionView> createState() => _GrowthProjectionViewState();
}

class _GrowthProjectionViewState extends State<_GrowthProjectionView> {
  late double _rate = widget.initialRate;
  ChartType _chartType = ChartType.area;

  /// Balance at the end of each year (index 0 = today), for the chart.
  List<double> _series() {
    final r = _rate / 100 / 12;
    final months = widget.years * 12;
    final out = <double>[widget.principal];
    var balance = widget.principal;
    for (var m = 1; m <= months; m++) {
      balance = balance * (1 + r) + widget.monthly;
      if (m % 12 == 0) out.add(balance);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final series = _series();
    final endBalance = series.last;
    final contributed =
        widget.principal + widget.monthly * widget.years * 12;
    final growth = math.max(endBalance - contributed, 0).toDouble();

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${money(widget.principal)} start · ${money(widget.monthly)}/mo '
              '· ${widget.years} years',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              money(endBalance),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
            Text(
              'projected in ${widget.years} years at ${pct(_rate)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            // On-widget display control: a generic style choice handled
            // locally, not by asking the model.
            Align(
              alignment: Alignment.centerRight,
              child: SegmentedButton<ChartType>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(
                    value: ChartType.area,
                    icon: Icon(Icons.area_chart, size: 18),
                  ),
                  ButtonSegment(
                    value: ChartType.line,
                    icon: Icon(Icons.show_chart, size: 18),
                  ),
                  ButtonSegment(
                    value: ChartType.bar,
                    icon: Icon(Icons.bar_chart, size: 18),
                  ),
                ],
                selected: {_chartType},
                onSelectionChanged: (s) =>
                    setState(() => _chartType = s.first),
              ),
            ),
            const SizedBox(height: 8),
            InteractiveChart(
              values: series,
              type: _chartType,
              labelBuilder: (i, v) => 'Year $i\n${money(v)}',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Breakdown(
                    label: 'You contribute',
                    value: contributed,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: _Breakdown(
                    label: 'Growth',
                    value: growth,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Assumed return', style: theme.textTheme.labelLarge),
                const Spacer(),
                Text(
                  pct(_rate),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: _rate,
              min: 1,
              max: 12,
              onChanged: (v) => setState(() => _rate = v),
            ),
            ApplyActionButton(
              label: 'Start this plan',
              onPressed: () => widget.onApply(
                'Invest ${money(widget.principal)} + '
                '${money(widget.monthly)}/mo for ${widget.years} years '
                '(projected ${money(endBalance)})',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          money(value),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
