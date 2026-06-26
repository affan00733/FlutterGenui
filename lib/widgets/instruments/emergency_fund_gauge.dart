import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/format.dart';
import 'package:genui_template/statuses.dart';
import 'package:genui_template/tones.dart';
import 'package:genui_template/widgets/apply_action_button.dart';
import 'package:genui_template/widgets/provenance_tag.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// EmergencyFundGauge — how many months of expenses the user's cash covers, vs
/// a target (default 6 months). The user drags a monthly top-up to see how
/// fast they reach a fully funded cushion.
final emergencyFundGauge = CatalogItem(
  name: 'EmergencyFundGauge',
  dataSchema: S.object(
    description:
        'Shows how many months of expenses the emergency fund covers vs a '
        'target. Use for "is my emergency fund enough" / "how long would my '
        'savings last". The user drags a monthly top-up; the timeline updates.',
    properties: {
      'title': S.string(description: 'Short heading.'),
      'currentFund': S.number(description: 'Cash set aside, in dollars.'),
      'monthlyExpenses': S.number(description: 'Monthly essential expenses.'),
      'targetMonths': S.integer(description: 'Target months of cover (def 6).'),
      'monthlyContribution': S.number(description: 'Starting monthly top-up.'),
      'tone': S.string(
        description: 'Palette that fits the topic.',
        enumValues: InstrumentTone.names,
      ),
      'source': S.string(
        description: 'Set to "your linked accounts" when from the snapshot.',
      ),
    },
    required: ['currentFund', 'monthlyExpenses'],
  ),
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "EmergencyFundGauge",
          "title": "Is your safety net big enough?",
          "currentFund": 18000,
          "monthlyExpenses": 4300,
          "targetMonths": 6,
          "monthlyContribution": 400,
          "tone": "amber"
        }
      ]
    ''',
  ],
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    num readNum(String key, num fallback) => (data[key] as num?) ?? fallback;

    return Toned(
      tone: InstrumentTone.fromName(data['tone'] as String?),
      child: _EmergencyFundView(
        title: (data['title'] as String?) ?? 'Emergency fund',
        currentFund: readNum('currentFund', 0).toDouble(),
        monthlyExpenses: readNum('monthlyExpenses', 1).toDouble(),
        targetMonths: readNum('targetMonths', 6).toInt().clamp(1, 24),
        initialContribution: readNum('monthlyContribution', 0).toDouble(),
        source: data['source'] as String?,
        onApply: (summary) => itemContext.dispatchEvent(
          UserActionEvent(
            name: 'setEmergencyFundPlan',
            sourceComponentId: itemContext.id,
            context: {'summary': summary},
          ),
        ),
      ),
    );
  },
);

class _EmergencyFundView extends StatefulWidget {
  const _EmergencyFundView({
    required this.title,
    required this.currentFund,
    required this.monthlyExpenses,
    required this.targetMonths,
    required this.initialContribution,
    required this.source,
    required this.onApply,
  });

  final String title;
  final double currentFund;
  final double monthlyExpenses;
  final int targetMonths;
  final double initialContribution;
  final String? source;
  final void Function(String summary) onApply;

  @override
  State<_EmergencyFundView> createState() => _EmergencyFundViewState();
}

class _EmergencyFundViewState extends State<_EmergencyFundView> {
  late double _contribution = widget.initialContribution;

  double get _monthsCovered => widget.monthlyExpenses == 0
      ? 0
      : widget.currentFund / widget.monthlyExpenses;

  double get _targetFund => widget.monthlyExpenses * widget.targetMonths;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final progress = (_targetFund == 0 ? 0.0 : widget.currentFund / _targetFund)
        .clamp(0.0, 1.0);
    final status = _monthsCovered >= widget.targetMonths
        ? Status.good
        : (_monthsCovered >= 3 ? Status.warn : Status.bad);
    final gap = math.max(_targetFund - widget.currentFund, 0).toDouble();
    final monthsToTarget = (_contribution <= 0 || gap == 0)
        ? null
        : (gap / _contribution).ceil();
    final sliderMax = math.max(_contribution * 2, 1000).ceilToDouble();

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
              'Target: ${widget.targetMonths} months (${money(_targetFund)})',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              '${_monthsCovered.toStringAsFixed(1)} months',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: status.color,
              ),
            ),
            Text(
              'of expenses covered (${money(widget.currentFund)})',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: scheme.surface,
                color: status.color,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(
                status: status,
                text: _monthsCovered >= widget.targetMonths
                    ? 'Fully funded — well done'
                    : monthsToTarget == null
                    ? 'Add a monthly top-up to close the ${money(gap)} gap'
                    : 'Fully funded in $monthsToTarget months at this rate',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Monthly top-up', style: theme.textTheme.labelLarge),
                const Spacer(),
                Text(
                  money(_contribution),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: _contribution.clamp(0, sliderMax),
              max: sliderMax,
              onChanged: (v) => setState(() => _contribution = v),
            ),
            ApplyActionButton(
              label: 'Set this savings plan',
              onPressed: () => widget.onApply(
                'Top up the emergency fund by ${money(_contribution)}/mo '
                'toward ${widget.targetMonths} months of cover',
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
