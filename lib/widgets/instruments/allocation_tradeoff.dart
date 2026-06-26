import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/format.dart';
import 'package:genui_template/statuses.dart';
import 'package:genui_template/tones.dart';
import 'package:genui_template/widgets/provenance_tag.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// AllocationTradeoff — an interactive "split a sum between two options" tool.
///
/// The model parameterizes it (amounts, rates, labels, a recommended split);
/// the user drags the slider and the projected outcome for each side recomputes
/// LIVE in Flutter — no round-trip to the model. This is the core Decision
/// Studio pattern: the AI generates a working instrument, not a static card.
final allocationTradeoff = CatalogItem(
  name: 'AllocationTradeoff',
  dataSchema: S.object(
    description:
        'An interactive tool for splitting a lump sum between two options '
        '(e.g. paying down debt vs investing). Use for "X vs Y" money '
        'decisions. The user drags a slider; outcomes recompute live.',
    properties: {
      'title': S.string(
        description:
            'Short heading, e.g. "Pay off debt or invest your bonus?".',
      ),
      'totalAmount': S.number(
        description: 'The lump sum being split, in dollars.',
      ),
      'optionALabel': S.string(description: 'Left option label.'),
      'optionARatePct': S.number(
        description:
            'Annual rate for option A as a percent. For paying down debt, use '
            'the APR (the interest rate avoided).',
      ),
      'optionBLabel': S.string(description: 'Right option label.'),
      'optionBRatePct': S.number(
        description:
            'Annual rate for option B as a percent (e.g. expected investment '
            'return).',
      ),
      'horizonYears': S.integer(
        description: 'Time horizon in years for the projection (1-40).',
      ),
      'recommendedToAPercent': S.number(
        description:
            'Optional 0-100 recommended share toward option A, per the '
            'business rules (e.g. high when a debt APR exceeds the expected '
            'return).',
      ),
      'note': S.string(
        description: 'Optional one-line explanation or disclaimer.',
      ),
      'tone': S.string(
        description:
            'Palette that fits the topic (debt/risk lean amber or rose). One '
            'of the allowed names.',
        enumValues: InstrumentTone.names,
      ),
      'source': S.string(
        description:
            'If a figure is pre-filled from the user snapshot, set this to '
            'e.g. "your linked accounts" to show a data-source tag.',
      ),
    },
    required: [
      'totalAmount',
      'optionALabel',
      'optionARatePct',
      'optionBLabel',
      'optionBRatePct',
    ],
  ),
  exampleData: [
    () => r'''
      [
        {
          "id": "root",
          "component": "AllocationTradeoff",
          "title": "Pay off your card or invest the $10,000?",
          "totalAmount": 10000,
          "optionALabel": "Pay off credit card",
          "optionARatePct": 22,
          "optionBLabel": "Invest in index fund",
          "optionBRatePct": 7,
          "horizonYears": 5,
          "recommendedToAPercent": 100,
          "note": "Your 22% card costs more than the market is likely to return.",
          "tone": "amber"
        }
      ]
    ''',
    () => '''
      [
        {
          "id": "root",
          "component": "AllocationTradeoff",
          "title": "Pay down your student loan or invest?",
          "totalAmount": 5000,
          "optionALabel": "Pay student loan",
          "optionARatePct": 6,
          "optionBLabel": "Invest in index fund",
          "optionBRatePct": 7,
          "horizonYears": 10,
          "recommendedToAPercent": 40,
          "note": "A close call: investing edges ahead, but paying the loan is a guaranteed return."
        }
      ]
    ''',
  ],
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    num readNum(String key, num fallback) =>
        (data[key] as num?) ?? fallback;
    String readStr(String key, String fallback) =>
        (data[key] as String?) ?? fallback;

    return Toned(
      tone: InstrumentTone.fromName(data['tone'] as String?),
      child: _AllocationTradeoffView(
        title: readStr('title', 'Allocation trade-off'),
        total: readNum('totalAmount', 0).toDouble(),
        optionALabel: readStr('optionALabel', 'Option A'),
        optionARate: readNum('optionARatePct', 0).toDouble(),
        optionBLabel: readStr('optionBLabel', 'Option B'),
        optionBRate: readNum('optionBRatePct', 0).toDouble(),
        horizonYears: readNum('horizonYears', 5).toInt().clamp(1, 40),
        recommendedToA: (data['recommendedToAPercent'] as num?)?.toDouble(),
        note: data['note'] as String?,
        source: data['source'] as String?,
        // The "act" hook: dispatch the chosen split back to the AI, which
        // confirms with a ConfirmationCard.
        onApply: (summary) => itemContext.dispatchEvent(
          UserActionEvent(
            name: 'applyAllocation',
            sourceComponentId: itemContext.id,
            context: {'summary': summary},
          ),
        ),
      ),
    );
  },
);

class _AllocationTradeoffView extends StatefulWidget {
  const _AllocationTradeoffView({
    required this.title,
    required this.total,
    required this.optionALabel,
    required this.optionARate,
    required this.optionBLabel,
    required this.optionBRate,
    required this.horizonYears,
    required this.recommendedToA,
    required this.note,
    required this.source,
    required this.onApply,
  });

  final String title;
  final double total;
  final String optionALabel;
  final double optionARate;
  final String optionBLabel;
  final double optionBRate;
  final int horizonYears;
  final double? recommendedToA;
  final String? note;
  final String? source;
  final void Function(String summary) onApply;

  @override
  State<_AllocationTradeoffView> createState() =>
      _AllocationTradeoffViewState();
}

class _AllocationTradeoffViewState extends State<_AllocationTradeoffView> {
  late double _shareToA = (widget.recommendedToA ?? 50) / 100;

  /// Compound benefit of putting [amount] to work at [ratePct] for the horizon.
  double _benefit(double amount, double ratePct) =>
      amount * (math.pow(1 + ratePct / 100, widget.horizonYears) - 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final amountA = widget.total * _shareToA;
    final amountB = widget.total * (1 - _shareToA);
    final benefitA = _benefit(amountA, widget.optionARate);
    final benefitB = _benefit(amountB, widget.optionBRate);
    final aWins = benefitA >= benefitB;
    final pctA = (_shareToA * 100).round();
    final pctB = 100 - pctA;

    // Value-driven status: how far the current split is from the optimal one
    // (100% to the higher-return option). Colour shifts good -> bad live.
    final betterIsA = widget.optionARate >= widget.optionBRate;
    final distanceFromBest = betterIsA ? (1 - _shareToA) : _shareToA;
    final status = distanceFromBest < 0.15
        ? Status.good
        : (distanceFromBest < 0.5 ? Status.warn : Status.bad);
    final statusText = switch (status) {
      Status.good => 'Optimal split',
      Status.warn => 'Could be better',
      Status.bad => 'Costing you money',
    };
    final aheadText = aWins
        ? '${widget.optionALabel} ahead by ${money(benefitA - benefitB)}'
        : '${widget.optionBLabel} ahead by ${money(benefitB - benefitA)}';

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
              'Splitting ${money(widget.total)} over ${widget.horizonYears} '
              'years',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _OptionStat(
                    label: widget.optionALabel,
                    amount: amountA,
                    benefitLabel: 'Interest saved',
                    benefit: benefitA,
                    rate: widget.optionARate,
                    highlighted: aWins,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OptionStat(
                    label: widget.optionBLabel,
                    amount: amountB,
                    benefitLabel: 'Projected growth',
                    benefit: benefitB,
                    rate: widget.optionBRate,
                    highlighted: !aWins,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Flexible(
                  child: Text(
                    '$pctA% to ${widget.optionALabel}',
                    style: theme.textTheme.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '$pctB% to ${widget.optionBLabel}',
                    style: theme.textTheme.labelLarge,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Slider(
              value: _shareToA,
              onChanged: (v) => setState(() => _shareToA = v),
            ),
            if (widget.recommendedToA != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(
                    () => _shareToA = widget.recommendedToA! / 100,
                  ),
                  icon: const Icon(Icons.recommend, size: 18),
                  label: Text(
                    'Recommended: ${widget.recommendedToA!.round()}% to '
                    '${widget.optionALabel}',
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // Banner colour is value-driven: green when the split is optimal,
            // red when it is leaving money on the table.
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: status.color.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(status.icon, color: status.color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$statusText · $aheadText over ${widget.horizonYears} '
                      'years.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: status.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.note != null) ...[
              const SizedBox(height: 10),
              Text(
                widget.note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => widget.onApply(
                  'Put ${money(amountA)} toward ${widget.optionALabel} and '
                  '${money(amountB)} toward ${widget.optionBLabel}',
                ),
                icon: const Icon(Icons.check),
                label: const Text('Apply this plan'),
              ),
            ),
            if (widget.source != null) ...[
              const SizedBox(height: 10),
              ProvenanceTag(source: widget.source!),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionStat extends StatelessWidget {
  const _OptionStat({
    required this.label,
    required this.amount,
    required this.benefitLabel,
    required this.benefit,
    required this.rate,
    required this.highlighted,
  });

  final String label;
  final double amount;
  final String benefitLabel;
  final double benefit;
  final double rate;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted ? scheme.primary : scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: highlighted ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            money(amount),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: highlighted ? scheme.onPrimary : scheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$benefitLabel @ ${pct(rate)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: highlighted
                  ? scheme.onPrimary.withValues(alpha: 0.85)
                  : scheme.onSurfaceVariant,
            ),
          ),
          Text(
            '+${money(benefit)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: highlighted ? scheme.onPrimary : scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
