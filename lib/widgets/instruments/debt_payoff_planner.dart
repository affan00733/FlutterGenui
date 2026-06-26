import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/format.dart';
import 'package:genui_template/statuses.dart';
import 'package:genui_template/tones.dart';
import 'package:genui_template/widgets/apply_action_button.dart';
import 'package:genui_template/widgets/provenance_tag.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// DebtPayoffPlanner — compares the snowball (smallest balance first) and
/// avalanche (highest APR first) strategies across several debts. The user
/// toggles the strategy and drags an extra-payment slider; the debt-free date,
/// total interest, and which strategy wins update live.
final debtPayoffPlanner = CatalogItem(
  name: 'DebtPayoffPlanner',
  dataSchema: S.object(
    description:
        'Compares debt-payoff strategies (snowball vs avalanche) across '
        'multiple debts. Use when the user has several debts and asks how to '
        'pay them off. The user toggles strategy and adds an extra payment.',
    properties: {
      'title': S.string(description: 'Short heading.'),
      'debts': S.list(
        description: 'The debts to pay off.',
        items: S.object(
          properties: {
            'name': S.string(description: 'Debt name, e.g. "Visa".'),
            'balance': S.number(description: 'Current balance in dollars.'),
            'apr': S.number(description: 'Annual interest rate, percent.'),
            'minPayment': S.number(
              description: 'Minimum monthly payment in dollars.',
            ),
          },
          required: ['name', 'balance', 'apr'],
        ),
      ),
      'extraMonthly': S.number(
        description: 'Starting extra monthly payment (default 0).',
      ),
      'tone': S.string(
        description: 'Palette (debt leans amber or rose).',
        enumValues: InstrumentTone.names,
      ),
      'source': S.string(
        description: 'Set to "your linked accounts" when from the snapshot.',
      ),
    },
    required: ['debts'],
  ),
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "DebtPayoffPlanner",
          "title": "Crush your debt",
          "debts": [
            {"name": "Store card", "balance": 1200, "apr": 26, "minPayment": 35},
            {"name": "Visa", "balance": 6400, "apr": 22, "minPayment": 160},
            {"name": "Car loan", "balance": 9000, "apr": 6, "minPayment": 240}
          ],
          "extraMonthly": 300,
          "tone": "amber"
        }
      ]
    ''',
  ],
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    final debts = ((data['debts'] as List?) ?? const [])
        .whereType<Map<String, Object?>>()
        .map(_Debt.fromMap)
        .where((d) => d.balance > 0)
        .toList();

    return Toned(
      tone: InstrumentTone.fromName(data['tone'] as String?),
      child: _DebtPayoffView(
        title: (data['title'] as String?) ?? 'Debt payoff plan',
        debts: debts,
        initialExtra: ((data['extraMonthly'] as num?) ?? 0).toDouble(),
        source: data['source'] as String?,
        onApply: (summary) => itemContext.dispatchEvent(
          UserActionEvent(
            name: 'applyDebtPlan',
            sourceComponentId: itemContext.id,
            context: {'summary': summary},
          ),
        ),
      ),
    );
  },
);

class _Debt {
  _Debt({
    required this.name,
    required this.balance,
    required this.apr,
    required this.minPayment,
  });

  factory _Debt.fromMap(Map<String, Object?> map) {
    final balance = ((map['balance'] as num?) ?? 0).toDouble();
    final min = (map['minPayment'] as num?)?.toDouble();
    return _Debt(
      name: (map['name'] as String?) ?? 'Debt',
      balance: balance,
      apr: ((map['apr'] as num?) ?? 0).toDouble(),
      // Sensible default minimum if the model didn't supply one.
      minPayment: min ?? math.max(balance * 0.02, 25),
    );
  }

  final String name;
  double balance;
  final double apr;
  final double minPayment;
}

enum _Strategy { avalanche, snowball }

typedef _Result = ({int months, double interest});

class _DebtPayoffView extends StatefulWidget {
  const _DebtPayoffView({
    required this.title,
    required this.debts,
    required this.initialExtra,
    required this.source,
    required this.onApply,
  });

  final String title;
  final List<_Debt> debts;
  final double initialExtra;
  final String? source;
  final void Function(String summary) onApply;

  @override
  State<_DebtPayoffView> createState() => _DebtPayoffViewState();
}

class _DebtPayoffViewState extends State<_DebtPayoffView> {
  late double _extra = widget.initialExtra;
  _Strategy _strategy = _Strategy.avalanche;

  /// The payoff order for a strategy: avalanche = highest APR first,
  /// snowball = smallest balance first.
  List<_Debt> _order(List<_Debt> debts, _Strategy strategy) {
    final sorted = [...debts];
    if (strategy == _Strategy.avalanche) {
      sorted.sort((a, b) => b.apr.compareTo(a.apr));
    } else {
      sorted.sort((a, b) => a.balance.compareTo(b.balance));
    }
    return sorted;
  }

  /// Simulates paying every minimum plus [extra] (rolled onto the target debt
  /// by [strategy]) until all debts are clear.
  _Result _simulate(_Strategy strategy, double extra) {
    final debts = widget.debts
        .map(
          (d) => _Debt(
            name: d.name,
            balance: d.balance,
            apr: d.apr,
            minPayment: d.minPayment,
          ),
        )
        .toList();
    var months = 0;
    var totalInterest = 0.0;

    while (debts.any((d) => d.balance > 0.01) && months < 1200) {
      months++;
      var pool = extra;
      // Accrue interest and pay minimums.
      for (final d in debts) {
        if (d.balance <= 0) continue;
        final interest = d.balance * d.apr / 100 / 12;
        d.balance += interest;
        totalInterest += interest;
        final pay = math.min(d.minPayment, d.balance);
        d.balance -= pay;
      }
      // Roll the extra onto the target debts in strategy order.
      for (final d in _order(debts, strategy)) {
        if (pool <= 0) break;
        if (d.balance <= 0) continue;
        final pay = math.min(pool, d.balance);
        d.balance -= pay;
        pool -= pay;
      }
    }
    return (months: months, interest: totalInterest);
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

    final totalBalance = widget.debts.fold<double>(0, (s, d) => s + d.balance);
    final avalanche = _simulate(_Strategy.avalanche, _extra);
    final snowball = _simulate(_Strategy.snowball, _extra);
    final selected = _strategy == _Strategy.avalanche ? avalanche : snowball;
    final interestGap = (snowball.interest - avalanche.interest).abs();
    final sliderMax = math.max(totalBalance * 0.05, 500).ceilToDouble();

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
              '${widget.debts.length} debts · ${money(totalBalance)} total',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Center(
              child: SegmentedButton<_Strategy>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _Strategy.avalanche,
                    label: Text('Avalanche'),
                  ),
                  ButtonSegment(
                    value: _Strategy.snowball,
                    label: Text('Snowball'),
                  ),
                ],
                selected: {_strategy},
                onSelectionChanged: (s) =>
                    setState(() => _strategy = s.first),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Debt-free in',
                    value: _duration(selected.months),
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Total interest',
                    value: money(selected.interest),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(
                status: _strategy == _Strategy.avalanche
                    ? Status.good
                    : Status.warn,
                text: _strategy == _Strategy.avalanche
                    ? 'Avalanche saves ${money(interestGap)} in interest'
                    : 'Avalanche would save ${money(interestGap)} more',
              ),
            ),
            const SizedBox(height: 12),
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
            const Divider(height: 24),
            Text('Payoff order', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            for (final (i, d) in _order(widget.debts, _strategy).indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: scheme.primary,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(d.name)),
                    Text(
                      '${money(d.balance)} · ${pct(d.apr)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ApplyActionButton(
              label: 'Start this payoff plan',
              onPressed: () => widget.onApply(
                'Start the ${_strategy.name} plan with ${money(_extra)}/mo '
                'extra — debt-free in ${_duration(selected.months)}',
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
