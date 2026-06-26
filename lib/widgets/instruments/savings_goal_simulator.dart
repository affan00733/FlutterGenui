import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/format.dart';
import 'package:genui_template/tones.dart';
import 'package:genui_template/widgets/apply_action_button.dart';
import 'package:genui_template/widgets/provenance_tag.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// SavingsGoalSimulator — an interactive "will I hit my goal?" tool.
///
/// The model parameterizes the goal, timeline, starting savings and expected
/// return; the user drags the monthly-contribution slider and the projected end
/// balance, progress ring, and on-track status recompute live in Flutter.
final savingsGoalSimulator = CatalogItem(
  name: 'SavingsGoalSimulator',
  dataSchema: S.object(
    description:
        r'An interactive savings projector for "reach $X by year Y" goals. '
        'The user drags a monthly-contribution slider; the projected balance '
        'and whether they are on track update live.',
    properties: {
      'title': S.string(description: 'Short heading for the goal.'),
      'goalAmount': S.number(description: 'Target amount in dollars.'),
      'targetYears': S.integer(description: 'Years until the goal (1-40).'),
      'currentSavings': S.number(
        description: 'Amount already saved toward this goal (dollars).',
      ),
      'expectedReturnPct': S.number(
        description: 'Assumed annual return as a percent (1-12).',
      ),
      'startingMonthly': S.number(
        description:
            'Optional starting value for the monthly-contribution slider. If '
            'omitted, the tool starts at the amount needed to hit the goal.',
      ),
      'tone': S.string(
        description: 'Palette that fits the topic (saving leans ocean/teal).',
        enumValues: InstrumentTone.names,
      ),
      'source': S.string(
        description: 'Set to "your linked accounts" when from the snapshot.',
      ),
    },
    required: ['goalAmount', 'targetYears'],
  ),
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "SavingsGoalSimulator",
          "title": "House down payment",
          "goalAmount": 50000,
          "targetYears": 4,
          "currentSavings": 8000,
          "expectedReturnPct": 5,
          "tone": "ocean"
        }
      ]
    ''',
    () => r'''
      [
        {
          "id": "root",
          "component": "SavingsGoalSimulator",
          "title": "Build a $15,000 emergency fund",
          "goalAmount": 15000,
          "targetYears": 2,
          "currentSavings": 3000,
          "expectedReturnPct": 4
        }
      ]
    ''',
  ],
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    num readNum(String key, num fallback) => (data[key] as num?) ?? fallback;

    return Toned(
      tone: InstrumentTone.fromName(data['tone'] as String?),
      child: _SavingsGoalView(
        title: (data['title'] as String?) ?? 'Savings goal',
        goal: readNum('goalAmount', 0).toDouble(),
        years: readNum('targetYears', 5).toInt().clamp(1, 40),
        current: readNum('currentSavings', 0).toDouble(),
        returnPct: readNum('expectedReturnPct', 5).toDouble().clamp(1, 12),
        startingMonthly: (data['startingMonthly'] as num?)?.toDouble(),
        source: data['source'] as String?,
        onApply: (summary) => itemContext.dispatchEvent(
          UserActionEvent(
            name: 'setGoal',
            sourceComponentId: itemContext.id,
            context: {'summary': summary},
          ),
        ),
      ),
    );
  },
);

class _SavingsGoalView extends StatefulWidget {
  const _SavingsGoalView({
    required this.title,
    required this.goal,
    required this.years,
    required this.current,
    required this.returnPct,
    required this.startingMonthly,
    required this.source,
    required this.onApply,
  });

  final String title;
  final double goal;
  final int years;
  final double current;
  final double returnPct;
  final double? startingMonthly;
  final String? source;
  final void Function(String summary) onApply;

  @override
  State<_SavingsGoalView> createState() => _SavingsGoalViewState();
}

class _SavingsGoalViewState extends State<_SavingsGoalView> {
  late double _monthly = widget.startingMonthly ?? _requiredMonthly();

  int get _months => widget.years * 12;
  double get _monthlyRate => widget.returnPct / 100 / 12;

  /// Future-value annuity factor for the horizon.
  double _annuityFactor() {
    final r = _monthlyRate;
    if (r == 0) return _months.toDouble();
    return (math.pow(1 + r, _months) - 1) / r;
  }

  double _grownCurrent() =>
      widget.current * math.pow(1 + _monthlyRate, _months);

  /// Monthly contribution needed to exactly hit the goal.
  double _requiredMonthly() {
    final remaining = widget.goal - _grownCurrent();
    if (remaining <= 0) return 0;
    return remaining / _annuityFactor();
  }

  double _projectedBalance() => _grownCurrent() + _monthly * _annuityFactor();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final projected = _projectedBalance();
    final progress = (projected / widget.goal).clamp(0.0, 1.0);
    final required = _requiredMonthly();
    final onTrack = projected >= widget.goal;
    final sliderMax = math.max(required * 2, 1000).ceilToDouble();

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
              'Goal ${money(widget.goal)} in ${widget.years} years · '
              '${pct(widget.returnPct)} return',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 92,
                        height: 92,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 9,
                          backgroundColor: scheme.surface,
                          color: onTrack ? scheme.primary : scheme.error,
                        ),
                      ),
                      Text(
                        '${(progress * 100).round()}%',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Projected: ${money(projected)}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        onTrack
                            ? 'On track — ${money(projected - widget.goal)} '
                                  'to spare.'
                            : 'Short by ${money(widget.goal - projected)}.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: onTrack ? scheme.primary : scheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Monthly contribution', style: theme.textTheme.labelLarge),
                const Spacer(),
                Text(
                  money(_monthly),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: _monthly.clamp(0, sliderMax),
              max: sliderMax,
              onChanged: (v) => setState(() => _monthly = v),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _monthly = required),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text('Set to on-track: ${money(required)}/mo'),
              ),
            ),
            ApplyActionButton(
              label: 'Set this goal',
              onPressed: () => widget.onApply(
                'Save ${money(_monthly)}/mo toward "${widget.title}" '
                '(${money(widget.goal)} in ${widget.years} years)',
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
