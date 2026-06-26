import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/format.dart';
import 'package:genui_template/statuses.dart';
import 'package:genui_template/tones.dart';
import 'package:genui_template/widgets/apply_action_button.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// RentVsBuy — compares the total cost of renting vs buying over a horizon the
/// user drags, accounting for the mortgage, ownership costs, equity built, and
/// home appreciation, and shows the break-even year.
final rentVsBuy = CatalogItem(
  name: 'RentVsBuy',
  dataSchema: S.object(
    description:
        'Compares renting vs buying a home over time. Use for "should I rent '
        'or buy" questions. The user drags how long they stay; the cheaper '
        'option and the break-even year update live.',
    properties: {
      'title': S.string(description: 'Short heading.'),
      'monthlyRent': S.number(description: 'Current/expected monthly rent.'),
      'homePrice': S.number(description: 'Purchase price of the home.'),
      'downPayment': S.number(description: 'Cash down payment.'),
      'mortgageRatePct': S.number(description: 'Mortgage APR (default 6.5).'),
      'monthlyOwnershipCost': S.number(
        description: 'Monthly taxes + insurance + upkeep (est ~1%/yr of price).',
      ),
      'appreciationPct': S.number(
        description: 'Annual home appreciation percent (default 3).',
      ),
      'yearsStay': S.integer(description: 'Starting years to stay.'),
      'tone': S.string(
        description: 'Palette that fits the topic.',
        enumValues: InstrumentTone.names,
      ),
    },
    required: ['monthlyRent', 'homePrice'],
  ),
  exampleData: [
    () => r'''
      [
        {
          "id": "root",
          "component": "RentVsBuy",
          "title": "Rent or buy a $450,000 home?",
          "monthlyRent": 2400,
          "homePrice": 450000,
          "downPayment": 90000,
          "mortgageRatePct": 6.5,
          "monthlyOwnershipCost": 750,
          "appreciationPct": 3,
          "yearsStay": 7,
          "tone": "indigo"
        }
      ]
    ''',
  ],
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    num readNum(String key, num fallback) => (data[key] as num?) ?? fallback;

    return Toned(
      tone: InstrumentTone.fromName(data['tone'] as String?),
      child: _RentVsBuyView(
        title: (data['title'] as String?) ?? 'Rent vs buy',
        monthlyRent: readNum('monthlyRent', 0).toDouble(),
        homePrice: readNum('homePrice', 0).toDouble(),
        downPayment: readNum('downPayment', 0).toDouble(),
        ratePct: readNum('mortgageRatePct', 6.5).toDouble(),
        monthlyOwnershipCost: readNum('monthlyOwnershipCost', 0).toDouble(),
        appreciationPct: readNum('appreciationPct', 3).toDouble(),
        initialYears: readNum('yearsStay', 7).toInt().clamp(1, 30),
        onApply: (summary) => itemContext.dispatchEvent(
          UserActionEvent(
            name: 'chooseHousing',
            sourceComponentId: itemContext.id,
            context: {'summary': summary},
          ),
        ),
      ),
    );
  },
);

typedef _Costs = ({double rent, double own});

class _RentVsBuyView extends StatefulWidget {
  const _RentVsBuyView({
    required this.title,
    required this.monthlyRent,
    required this.homePrice,
    required this.downPayment,
    required this.ratePct,
    required this.monthlyOwnershipCost,
    required this.appreciationPct,
    required this.initialYears,
    required this.onApply,
  });

  final String title;
  final double monthlyRent;
  final double homePrice;
  final double downPayment;
  final double ratePct;
  final double monthlyOwnershipCost;
  final double appreciationPct;
  final int initialYears;
  final void Function(String summary) onApply;

  @override
  State<_RentVsBuyView> createState() => _RentVsBuyViewState();
}

class _RentVsBuyViewState extends State<_RentVsBuyView> {
  late double _years = widget.initialYears.toDouble();

  double get _loan => math.max(0, widget.homePrice - widget.downPayment);

  double _monthlyPI() {
    final r = widget.ratePct / 100 / 12;
    if (_loan <= 0) return 0;
    if (r == 0) return _loan / 360;
    final f = math.pow(1 + r, 360);
    return _loan * r * f / (f - 1);
  }

  /// Total rent cost and net cost of owning over [years].
  _Costs _costsAt(int years) {
    final r = widget.ratePct / 100 / 12;
    final months = years * 12;
    final pi = _monthlyPI();
    var balance = _loan;
    var paid = widget.downPayment;
    for (var m = 0; m < months; m++) {
      final interest = balance * r;
      final principal = (pi - interest).clamp(0.0, balance);
      balance -= principal;
      paid += pi + widget.monthlyOwnershipCost;
    }
    final homeValue =
        widget.homePrice * math.pow(1 + widget.appreciationPct / 100, years);
    final equity = homeValue - balance;
    final own = paid - equity;
    final rent = widget.monthlyRent * months;
    return (rent: rent, own: own);
  }

  int? _breakEvenYear() {
    for (var y = 1; y <= 30; y++) {
      final c = _costsAt(y);
      if (c.own < c.rent) return y;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final costs = _costsAt(_years.round());
    final buyCheaper = costs.own < costs.rent;
    final gap = (costs.rent - costs.own).abs();
    final breakEven = _breakEvenYear();
    final years = _years.round();
    final verdict = buyCheaper
        ? 'Buying is ${money(gap)} cheaper over $years yrs'
        : 'Renting is ${money(gap)} cheaper over $years yrs';

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
              '${money(widget.monthlyRent)}/mo rent vs '
              '${money(widget.homePrice)} home',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Rent ${_years.round()} yrs',
                    value: money(costs.rent),
                    highlight: !buyCheaper,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Stat(
                    label: 'Buy (net cost)',
                    value: money(costs.own),
                    highlight: buyCheaper,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(status: Status.good, text: verdict),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Years you stay', style: theme.textTheme.labelLarge),
                const Spacer(),
                Text(
                  '${_years.round()} years',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: _years,
              min: 1,
              max: 30,
              divisions: 29,
              onChanged: (v) => setState(() => _years = v),
            ),
            Text(
              breakEven == null
                  ? 'Renting stays cheaper for at least 30 years.'
                  : 'Buying pulls ahead after year $breakEven.',
              style: theme.textTheme.bodySmall,
            ),
            ApplyActionButton(
              label: buyCheaper ? 'Plan to buy' : 'Plan to rent',
              onPressed: () => widget.onApply(
                buyCheaper
                    ? 'Buy the home — cheaper by ${money(gap)} over '
                          '${_years.round()} years'
                    : 'Keep renting — cheaper by ${money(gap)} over '
                          '${_years.round()} years',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.highlight,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? scheme.primaryContainer : scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
