import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/format.dart';
import 'package:genui_template/tones.dart';
import 'package:genui_template/widgets/apply_action_button.dart';
import 'package:genui_template/widgets/charts/donut_chart.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// RiskAllocation — an interactive risk dial that maps a risk level (1-5) to a
/// suggested asset allocation, drawn as a donut. The model only picks the
/// starting risk level; the allocations, return and volatility are computed
/// from a fixed, suitable table client-side (a guardrail in itself).
final riskAllocation = CatalogItem(
  name: 'RiskAllocation',
  dataSchema: S.object(
    description:
        'An interactive risk dial that shows the suggested stocks/bonds/cash '
        'mix for a chosen risk level as a donut chart. Use for "conservative '
        'vs aggressive", "how should I allocate", or risk-tolerance questions.',
    properties: {
      'title': S.string(description: 'Short heading.'),
      'initialRiskLevel': S.integer(
        description:
            'Starting risk level 1-5 (1 = conservative, 5 = aggressive). '
            'Pick based on their stated risk tolerance.',
      ),
      'note': S.string(description: 'Optional one-line note.'),
      'tone': S.string(
        description: 'Palette that fits the topic. One of the allowed names.',
        enumValues: InstrumentTone.names,
      ),
    },
    required: ['initialRiskLevel'],
  ),
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "RiskAllocation",
          "title": "Conservative vs aggressive for your IRA",
          "initialRiskLevel": 3,
          "note": "Based on your moderate risk tolerance."
        }
      ]
    ''',
    () => '''
      [
        {
          "id": "root",
          "component": "RiskAllocation",
          "title": "Aggressive growth for a 30-year horizon",
          "initialRiskLevel": 5,
          "note": "A long runway lets you ride out short-term volatility."
        }
      ]
    ''',
  ],
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    return Toned(
      tone: InstrumentTone.fromName(data['tone'] as String?),
      child: _RiskAllocationView(
        title: (data['title'] as String?) ?? 'Suggested allocation',
        initialLevel: ((data['initialRiskLevel'] as num?) ?? 3)
            .toInt()
            .clamp(1, 5),
        note: data['note'] as String?,
        onApply: (summary) => itemContext.dispatchEvent(
          UserActionEvent(
            name: 'applyRiskAllocation',
            sourceComponentId: itemContext.id,
            context: {'summary': summary},
          ),
        ),
      ),
    );
  },
);

/// A fixed, suitability-aware allocation profile per risk level.
typedef _Profile = ({
  String label,
  int stocks,
  int bonds,
  int cash,
  double expectedReturn,
  String volatility,
});

const Map<int, _Profile> _profiles = {
  1: (
    label: 'Conservative',
    stocks: 20,
    bonds: 50,
    cash: 30,
    expectedReturn: 3.5,
    volatility: 'Low',
  ),
  2: (
    label: 'Cautious',
    stocks: 40,
    bonds: 45,
    cash: 15,
    expectedReturn: 5,
    volatility: 'Low–Medium',
  ),
  3: (
    label: 'Moderate',
    stocks: 60,
    bonds: 35,
    cash: 5,
    expectedReturn: 6.5,
    volatility: 'Medium',
  ),
  4: (
    label: 'Growth',
    stocks: 75,
    bonds: 22,
    cash: 3,
    expectedReturn: 7.5,
    volatility: 'Medium–High',
  ),
  5: (
    label: 'Aggressive',
    stocks: 90,
    bonds: 10,
    cash: 0,
    expectedReturn: 8.5,
    volatility: 'High',
  ),
};

class _RiskAllocationView extends StatefulWidget {
  const _RiskAllocationView({
    required this.title,
    required this.initialLevel,
    required this.note,
    required this.onApply,
  });

  final String title;
  final int initialLevel;
  final String? note;
  final void Function(String summary) onApply;

  @override
  State<_RiskAllocationView> createState() => _RiskAllocationViewState();
}

class _RiskAllocationViewState extends State<_RiskAllocationView> {
  late int _level = widget.initialLevel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = _profiles[_level]!;

    final stocksColor = scheme.primary;
    final bondsColor = scheme.tertiary;
    final cashColor = scheme.secondaryContainer;

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
              '${profile.label} · ~${pct(profile.expectedReturn)} expected · '
              '${profile.volatility} volatility',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                DonutChart(
                  segments: [
                    (
                      label: 'Stocks',
                      value: profile.stocks.toDouble(),
                      color: stocksColor,
                    ),
                    (
                      label: 'Bonds',
                      value: profile.bonds.toDouble(),
                      color: bondsColor,
                    ),
                    (
                      label: 'Cash',
                      value: profile.cash.toDouble(),
                      color: cashColor,
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LegendRow(
                        color: stocksColor,
                        label: 'Stocks',
                        percent: profile.stocks,
                      ),
                      _LegendRow(
                        color: bondsColor,
                        label: 'Bonds',
                        percent: profile.bonds,
                      ),
                      _LegendRow(
                        color: cashColor,
                        label: 'Cash',
                        percent: profile.cash,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Risk level', style: theme.textTheme.labelLarge),
                const Spacer(),
                Text(
                  profile.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: _level.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: profile.label,
              onChanged: (v) => setState(() => _level = v.round()),
            ),
            if (widget.note != null)
              Text(
                widget.note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ApplyActionButton(
              label: 'Apply this allocation',
              onPressed: () => widget.onApply(
                'Use a ${profile.label} allocation: ${profile.stocks}% stocks, '
                '${profile.bonds}% bonds, ${profile.cash}% cash',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.percent,
  });

  final Color color;
  final String label;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(
            '$percent%',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
