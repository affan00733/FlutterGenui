import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/format.dart';
import 'package:genui_template/statuses.dart';
import 'package:genui_template/tones.dart';
import 'package:genui_template/widgets/apply_action_button.dart';
import 'package:genui_template/widgets/provenance_tag.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// AffordabilityCheck — "can I afford this?" The user drags a financing-months
/// slider; the monthly payment, money left over, and a verdict (comfortable /
/// stretch / risky) update live.
final affordabilityCheck = CatalogItem(
  name: 'AffordabilityCheck',
  dataSchema: S.object(
    description:
        'Checks whether the user can afford a purchase. Use for "can I afford" '
        'questions. The user drags a financing-term slider (0 = pay in full); '
        'the verdict updates live.',
    properties: {
      'title': S.string(description: 'Short heading.'),
      'itemName': S.string(description: 'What is being bought.'),
      'price': S.number(description: 'Purchase price in dollars.'),
      'monthlyIncome': S.number(description: 'Monthly take-home pay.'),
      'monthlyExpenses': S.number(description: 'Current monthly expenses.'),
      'financingMonths': S.integer(
        description: 'Starting financing term in months (0 = pay in full).',
      ),
      'aprPct': S.number(description: 'Financing APR percent (0 if none).'),
      'tone': S.string(
        description: 'Palette that fits the topic.',
        enumValues: InstrumentTone.names,
      ),
      'source': S.string(
        description:
            'Set to "your linked accounts" when income/expenses come from the '
            'snapshot.',
      ),
    },
    required: ['price', 'monthlyIncome', 'monthlyExpenses'],
  ),
  exampleData: [
    () => r'''
      [
        {
          "id": "root",
          "component": "AffordabilityCheck",
          "title": "Can you afford a $2,400 laptop?",
          "itemName": "laptop",
          "price": 2400,
          "monthlyIncome": 7200,
          "monthlyExpenses": 4300,
          "financingMonths": 12,
          "aprPct": 0,
          "tone": "indigo",
          "source": "your linked accounts"
        }
      ]
    ''',
  ],
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    num readNum(String key, num fallback) => (data[key] as num?) ?? fallback;

    return Toned(
      tone: InstrumentTone.fromName(data['tone'] as String?),
      child: _AffordView(
        title: (data['title'] as String?) ?? 'Affordability check',
        itemName: (data['itemName'] as String?) ?? 'this',
        price: readNum('price', 0).toDouble(),
        income: readNum('monthlyIncome', 0).toDouble(),
        expenses: readNum('monthlyExpenses', 0).toDouble(),
        initialMonths: readNum('financingMonths', 0).toInt().clamp(0, 60),
        apr: readNum('aprPct', 0).toDouble(),
        source: data['source'] as String?,
        onApply: (summary) => itemContext.dispatchEvent(
          UserActionEvent(
            name: 'savePurchasePlan',
            sourceComponentId: itemContext.id,
            context: {'summary': summary},
          ),
        ),
      ),
    );
  },
);

class _AffordView extends StatefulWidget {
  const _AffordView({
    required this.title,
    required this.itemName,
    required this.price,
    required this.income,
    required this.expenses,
    required this.initialMonths,
    required this.apr,
    required this.source,
    required this.onApply,
  });

  final String title;
  final String itemName;
  final double price;
  final double income;
  final double expenses;
  final int initialMonths;
  final double apr;
  final String? source;
  final void Function(String summary) onApply;

  @override
  State<_AffordView> createState() => _AffordViewState();
}

class _AffordViewState extends State<_AffordView> {
  late double _months = widget.initialMonths.toDouble();

  double get _surplus => widget.income - widget.expenses;

  double _monthlyPayment() {
    if (_months < 1) return 0; // paid in full up front
    final r = widget.apr / 100 / 12;
    if (r == 0) return widget.price / _months;
    final factor = math.pow(1 + r, _months);
    return widget.price * r * factor / (factor - 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final payment = _monthlyPayment();
    final payingInFull = _months < 1;
    final leftover = _surplus - payment;

    final Status status;
    final String verdict;
    if (payingInFull) {
      // Paying cash: judge against ~3 months of surplus as a soft cushion.
      if (widget.price <= _surplus * 3) {
        status = Status.good;
        verdict = 'Comfortable to pay in full';
      } else if (widget.price <= _surplus * 6) {
        status = Status.warn;
        verdict = 'A stretch to pay in full';
      } else {
        status = Status.bad;
        verdict = 'Too much to pay in full';
      }
    } else {
      if (leftover >= widget.income * 0.2) {
        status = Status.good;
        verdict = 'Comfortable';
      } else if (leftover >= 0) {
        status = Status.warn;
        verdict = 'Tight, but doable';
      } else {
        status = Status.bad;
        verdict = "Over budget — can't afford";
      }
    }

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
              '${money(widget.price)} · ${money(_surplus)}/mo surplus',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(status: status, text: verdict),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: payingInFull ? 'Pay now' : 'Per month',
                    value: payingInFull ? money(widget.price) : money(payment),
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Left each month',
                    value: payingInFull ? money(_surplus) : money(leftover),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('Spread over', style: theme.textTheme.labelLarge),
                const Spacer(),
                Text(
                  payingInFull ? 'Pay in full' : '${_months.round()} months',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: _months,
              max: 60,
              divisions: 60,
              onChanged: (v) => setState(() => _months = v),
            ),
            ApplyActionButton(
              label: 'Add to my plan',
              onPressed: () => widget.onApply(
                payingInFull
                    ? 'Buy ${widget.itemName} for ${money(widget.price)}, '
                          'paid in full'
                    : 'Buy ${widget.itemName} for ${money(widget.price)} over '
                          '${_months.round()} months at ${money(payment)}/mo',
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

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
