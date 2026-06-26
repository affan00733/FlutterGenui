import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/format.dart';
import 'package:genui_template/statuses.dart';
import 'package:genui_template/tones.dart';
import 'package:genui_template/widgets/apply_action_button.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// AmortizationSchedule — an interactive loan/mortgage payoff tool. The user
/// drags an "extra monthly payment" slider; the payoff time, total interest,
/// and the interest saved (with a value-driven status) update live.
final amortizationSchedule = CatalogItem(
  name: 'AmortizationSchedule',
  dataSchema: S.object(
    description:
        'An interactive loan/mortgage calculator. Use for loan or mortgage '
        'questions, especially "what if I pay extra". The user drags an extra '
        'monthly payment slider; payoff time and interest saved update live.',
    properties: {
      'title': S.string(description: 'Short heading.'),
      'loanAmount': S.number(description: 'Loan principal in dollars.'),
      'annualRatePct': S.number(description: 'Annual interest rate, percent.'),
      'years': S.integer(description: 'Loan term in years.'),
      'extraMonthly': S.number(
        description: 'Starting extra monthly payment (default 0).',
      ),
      'tone': S.string(
        description: 'Palette that fits the topic.',
        enumValues: InstrumentTone.names,
      ),
    },
    required: ['loanAmount', 'annualRatePct', 'years'],
  ),
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "AmortizationSchedule",
          "title": "Your 30-year mortgage",
          "loanAmount": 320000,
          "annualRatePct": 6.5,
          "years": 30,
          "extraMonthly": 0,
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
      child: _AmortView(
        title: (data['title'] as String?) ?? 'Loan payoff',
        loan: readNum('loanAmount', 0).toDouble(),
        ratePct: readNum('annualRatePct', 0).toDouble(),
        years: readNum('years', 1).toInt().clamp(1, 40),
        initialExtra: readNum('extraMonthly', 0).toDouble(),
        onApply: (summary) => itemContext.dispatchEvent(
          UserActionEvent(
            name: 'applyExtraPayment',
            sourceComponentId: itemContext.id,
            context: {'summary': summary},
          ),
        ),
      ),
    );
  },
);

typedef _Payoff = ({int months, double interest});

class _AmortView extends StatefulWidget {
  const _AmortView({
    required this.title,
    required this.loan,
    required this.ratePct,
    required this.years,
    required this.initialExtra,
    required this.onApply,
  });

  final String title;
  final double loan;
  final double ratePct;
  final int years;
  final double initialExtra;
  final void Function(String summary) onApply;

  @override
  State<_AmortView> createState() => _AmortViewState();
}

class _AmortViewState extends State<_AmortView> {
  late double _extra = widget.initialExtra;

  double get _monthlyRate => widget.ratePct / 100 / 12;
  int get _termMonths => widget.years * 12;

  /// The standard level monthly payment (principal + interest).
  double get _basePayment {
    final r = _monthlyRate;
    if (r == 0) return widget.loan / _termMonths;
    final factor = math.pow(1 + r, _termMonths);
    return widget.loan * r * factor / (factor - 1);
  }

  /// Simulates payoff with [extra] added each month.
  _Payoff _simulate(double extra) {
    final r = _monthlyRate;
    final payment = _basePayment + extra;
    var balance = widget.loan;
    var interest = 0.0;
    var months = 0;
    while (balance > 0.01 && months < 1200) {
      final monthInterest = balance * r;
      final principal = payment - monthInterest;
      if (principal <= 0) break; // payment can't cover interest
      balance -= principal;
      interest += monthInterest;
      months++;
    }
    return (months: months, interest: interest);
  }

  String _duration(int months) {
    final y = months ~/ 12;
    final m = months % 12;
    if (y == 0) return '$m mo';
    if (m == 0) return '$y yr';
    return '$y yr $m mo';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final baseline = _simulate(0);
    final withExtra = _simulate(_extra);
    final interestSaved = baseline.interest - withExtra.interest;
    final monthsSaved = baseline.months - withExtra.months;
    final sliderMax = math.max(_basePayment, 200).ceilToDouble();

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
              '${money(widget.loan)} at ${pct(widget.ratePct)} over '
              '${widget.years} years',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Monthly payment',
                    value: money(_basePayment + _extra),
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Paid off in',
                    value: _duration(withExtra.months),
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Total interest',
                    value: money(withExtra.interest),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_extra > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(
                  status: Status.good,
                  text:
                      'Saves ${money(interestSaved)} and '
                      '${_duration(monthsSaved)}',
                ),
              )
            else
              Text(
                'Drag below to see what paying extra saves.',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Extra / month', style: theme.textTheme.labelLarge),
                const Spacer(),
                Text(
                  money(_extra),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: _extra.clamp(0, sliderMax),
              max: sliderMax,
              onChanged: (v) => setState(() => _extra = v),
            ),
            ApplyActionButton(
              label: 'Apply this payment plan',
              onPressed: () => widget.onApply(
                _extra > 0
                    ? 'Pay ${money(_basePayment + _extra)}/mo '
                          '(${money(_extra)} extra) — debt-free in '
                          '${_duration(withExtra.months)}, saving '
                          '${money(interestSaved)}'
                    : 'Keep the standard ${money(_basePayment)}/mo payment',
              ),
            ),
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
