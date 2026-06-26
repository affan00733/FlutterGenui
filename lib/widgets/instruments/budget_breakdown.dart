import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/format.dart';
import 'package:genui_template/statuses.dart';
import 'package:genui_template/tones.dart';
import 'package:genui_template/widgets/apply_action_button.dart';
import 'package:genui_template/widgets/charts/donut_chart.dart';
import 'package:genui_template/widgets/provenance_tag.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// BudgetBreakdown — an interactive 50/30/20 budget split. The user drags the
/// needs/wants sliders; the donut, dollar amounts, and a value-driven status on
/// the savings rate update live.
final budgetBreakdown = CatalogItem(
  name: 'BudgetBreakdown',
  dataSchema: S.object(
    description:
        'An interactive monthly budget split into needs / wants / savings '
        '(the 50/30/20 rule). Use for budgeting or "where does my money go" '
        'questions. The user drags sliders; the savings-rate health updates.',
    properties: {
      'title': S.string(description: 'Short heading.'),
      'monthlyIncome': S.number(description: 'Monthly take-home pay.'),
      'needsPct': S.number(description: 'Starting needs %, default 50.'),
      'wantsPct': S.number(description: 'Starting wants %, default 30.'),
      'tone': S.string(
        description: 'Palette that fits the topic.',
        enumValues: InstrumentTone.names,
      ),
      'source': S.string(
        description: 'Set to "your linked accounts" when from the snapshot.',
      ),
    },
    required: ['monthlyIncome'],
  ),
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "BudgetBreakdown",
          "title": "Your monthly budget",
          "monthlyIncome": 7200,
          "needsPct": 50,
          "wantsPct": 30,
          "tone": "ocean"
        }
      ]
    ''',
  ],
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    num readNum(String key, num fallback) => (data[key] as num?) ?? fallback;

    return Toned(
      tone: InstrumentTone.fromName(data['tone'] as String?),
      child: _BudgetView(
        title: (data['title'] as String?) ?? 'Monthly budget',
        income: readNum('monthlyIncome', 0).toDouble(),
        initialNeeds: readNum('needsPct', 50).toDouble().clamp(0, 100),
        initialWants: readNum('wantsPct', 30).toDouble().clamp(0, 100),
        source: data['source'] as String?,
        onApply: (summary) => itemContext.dispatchEvent(
          UserActionEvent(
            name: 'setBudget',
            sourceComponentId: itemContext.id,
            context: {'summary': summary},
          ),
        ),
      ),
    );
  },
);

class _BudgetView extends StatefulWidget {
  const _BudgetView({
    required this.title,
    required this.income,
    required this.initialNeeds,
    required this.initialWants,
    required this.source,
    required this.onApply,
  });

  final String title;
  final double income;
  final double initialNeeds;
  final double initialWants;
  final String? source;
  final void Function(String summary) onApply;

  @override
  State<_BudgetView> createState() => _BudgetViewState();
}

class _BudgetViewState extends State<_BudgetView> {
  late double _needs = widget.initialNeeds;
  late double _wants = widget.initialWants.clamp(0, 100 - widget.initialNeeds);

  double get _savings => (100 - _needs - _wants).clamp(0, 100);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final needsAmt = widget.income * _needs / 100;
    final wantsAmt = widget.income * _wants / 100;
    final savingsAmt = widget.income * _savings / 100;

    final status = _savings >= 20
        ? Status.good
        : (_savings >= 10 ? Status.warn : Status.bad);
    final statusText = _savings >= 20
        ? 'Saving ${_savings.round()}% — healthy'
        : (_savings >= 10
              ? 'Saving ${_savings.round()}% — aim for 20%'
              : 'Saving ${_savings.round()}% — too low');

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
              '${money(widget.income)}/month',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                DonutChart(
                  segments: [
                    (label: 'Needs', value: _needs, color: scheme.secondary),
                    (label: 'Wants', value: _wants, color: scheme.primary),
                    (label: 'Savings', value: _savings, color: scheme.tertiary),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Row(
                        color: scheme.secondary,
                        label: 'Needs',
                        amount: needsAmt,
                      ),
                      _Row(
                        color: scheme.primary,
                        label: 'Wants',
                        amount: wantsAmt,
                      ),
                      _Row(
                        color: scheme.tertiary,
                        label: 'Savings',
                        amount: savingsAmt,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(status: status, text: statusText),
            ),
            const SizedBox(height: 8),
            _PctSlider(
              label: 'Needs',
              value: _needs,
              onChanged: (v) => setState(() {
                _needs = v;
                if (_needs + _wants > 100) _wants = 100 - _needs;
              }),
            ),
            _PctSlider(
              label: 'Wants',
              value: _wants,
              max: 100 - _needs,
              onChanged: (v) => setState(() => _wants = v),
            ),
            ApplyActionButton(
              label: 'Set this budget',
              onPressed: () => widget.onApply(
                'Budget ${money(widget.income)}/mo: needs ${_needs.round()}% '
                '(${money(needsAmt)}), wants ${_wants.round()}% '
                '(${money(wantsAmt)}), savings ${_savings.round()}% '
                '(${money(savingsAmt)})',
              ),
            ),
            if (widget.source != null) ...[
              const SizedBox(height: 6),
              ProvenanceTag(source: widget.source!),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.color, required this.label, required this.amount});

  final Color color;
  final String label;
  final double amount;

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
            money(amount),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PctSlider extends StatelessWidget {
  const _PctSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.max = 100,
  });

  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label, style: theme.textTheme.labelLarge),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0, max),
            max: max <= 0 ? 1 : max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${value.round()}%',
            textAlign: TextAlign.end,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
