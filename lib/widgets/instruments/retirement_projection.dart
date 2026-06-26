import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/format.dart';
import 'package:genui_template/statuses.dart';
import 'package:genui_template/tones.dart';
import 'package:genui_template/widgets/apply_action_button.dart';
import 'package:genui_template/widgets/provenance_tag.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// RetirementProjection — "will I have enough to retire?" Projects the nest egg
/// at retirement vs the amount needed (the 4% rule), and lets the user drag
/// their monthly contribution to see if they get on track.
final retirementProjection = CatalogItem(
  name: 'RetirementProjection',
  dataSchema: S.object(
    description:
        'Projects whether the user is on track to retire. Use for retirement '
        'questions ("can I retire at 60", "saving enough for retirement"). The '
        'user drags their monthly contribution; on-track status updates.',
    properties: {
      'title': S.string(description: 'Short heading.'),
      'currentAge': S.integer(description: "The user's current age."),
      'retirementAge': S.integer(description: 'Target retirement age.'),
      'currentSavings': S.number(description: 'Retirement savings so far.'),
      'monthlyContribution': S.number(description: 'Starting monthly saving.'),
      'expectedReturnPct': S.number(description: 'Assumed annual return %.'),
      'annualSpending': S.number(
        description: 'Desired annual spending in retirement (drives the goal).',
      ),
      'tone': S.string(
        description: 'Palette that fits the topic.',
        enumValues: InstrumentTone.names,
      ),
      'source': S.string(
        description: 'Set to "your linked accounts" when from the snapshot.',
      ),
    },
    required: [
      'currentAge',
      'retirementAge',
      'currentSavings',
      'annualSpending',
    ],
  ),
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "RetirementProjection",
          "title": "On track to retire at 65?",
          "currentAge": 32,
          "retirementAge": 65,
          "currentSavings": 32000,
          "monthlyContribution": 600,
          "expectedReturnPct": 6,
          "annualSpending": 50000,
          "tone": "teal"
        }
      ]
    ''',
  ],
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    num readNum(String key, num fallback) => (data[key] as num?) ?? fallback;

    return Toned(
      tone: InstrumentTone.fromName(data['tone'] as String?),
      child: _RetirementView(
        title: (data['title'] as String?) ?? 'Retirement projection',
        currentAge: readNum('currentAge', 30).toInt(),
        retirementAge: readNum('retirementAge', 65).toInt(),
        currentSavings: readNum('currentSavings', 0).toDouble(),
        initialMonthly: readNum('monthlyContribution', 0).toDouble(),
        returnPct: readNum('expectedReturnPct', 6).toDouble().clamp(1, 12),
        annualSpending: readNum('annualSpending', 40000).toDouble(),
        source: data['source'] as String?,
        onApply: (summary) => itemContext.dispatchEvent(
          UserActionEvent(
            name: 'setRetirementPlan',
            sourceComponentId: itemContext.id,
            context: {'summary': summary},
          ),
        ),
      ),
    );
  },
);

class _RetirementView extends StatefulWidget {
  const _RetirementView({
    required this.title,
    required this.currentAge,
    required this.retirementAge,
    required this.currentSavings,
    required this.initialMonthly,
    required this.returnPct,
    required this.annualSpending,
    required this.source,
    required this.onApply,
  });

  final String title;
  final int currentAge;
  final int retirementAge;
  final double currentSavings;
  final double initialMonthly;
  final double returnPct;
  final double annualSpending;
  final String? source;
  final void Function(String summary) onApply;

  @override
  State<_RetirementView> createState() => _RetirementViewState();
}

class _RetirementViewState extends State<_RetirementView> {
  late double _monthly = widget.initialMonthly;

  int get _years => math.max(0, widget.retirementAge - widget.currentAge);

  /// Needed nest egg via the 4% rule (25x annual spending).
  double get _needed => widget.annualSpending * 25;

  double _projected() {
    final r = widget.returnPct / 100 / 12;
    final n = _years * 12;
    final grownCurrent = widget.currentSavings * math.pow(1 + r, n);
    final factor = r == 0 ? n.toDouble() : (math.pow(1 + r, n) - 1) / r;
    return grownCurrent + _monthly * factor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final projected = _projected();
    final progress = (_needed == 0 ? 0.0 : projected / _needed).clamp(0.0, 1.0);
    final onTrack = projected >= _needed;
    final status = onTrack
        ? Status.good
        : (progress >= 0.7 ? Status.warn : Status.bad);
    final sliderMax = math.max(_monthly * 2, 2000).ceilToDouble();

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
              'Retiring at ${widget.retirementAge} · $_years years to go · '
              'need ${money(_needed)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              money(projected),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: status.color,
              ),
            ),
            Text('projected nest egg', style: theme.textTheme.bodySmall),
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
                text: onTrack
                    ? 'On track — ${money(projected - _needed)} to spare'
                    : '${money(_needed - projected)} short of your goal',
              ),
            ),
            const SizedBox(height: 12),
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
            ApplyActionButton(
              label: 'Set this retirement plan',
              onPressed: () => widget.onApply(
                'Save ${money(_monthly)}/mo for retirement at '
                '${widget.retirementAge} (projected ${money(projected)})',
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
