import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/format.dart';
import 'package:genui_template/statuses.dart';
import 'package:genui_template/tones.dart';
import 'package:genui_template/widgets/apply_action_button.dart';
import 'package:genui_template/widgets/charts/donut_chart.dart';
import 'package:genui_template/widgets/provenance_tag.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// PaycheckBreakdown — where a monthly paycheck goes (401k, tax, take-home).
/// The user drags their 401k contribution to see the trade-off between
/// take-home pay now and retirement saving.
final paycheckBreakdown = CatalogItem(
  name: 'PaycheckBreakdown',
  dataSchema: S.object(
    description:
        'Breaks a monthly paycheck into 401k, estimated tax, and take-home '
        'pay. Use for "where does my paycheck go" / take-home / 401k questions. '
        'The user drags the 401k percent; take-home updates live.',
    properties: {
      'title': S.string(description: 'Short heading.'),
      'grossMonthly': S.number(description: 'Gross monthly pay before tax.'),
      'taxRatePct': S.number(
        description: 'Estimated effective tax rate percent (default 22).',
      ),
      'retirement401kPct': S.number(
        description: 'Starting 401k contribution percent (default 5).',
      ),
      'tone': S.string(
        description: 'Palette that fits the topic.',
        enumValues: InstrumentTone.names,
      ),
      'source': S.string(
        description: 'Set to "your linked accounts" when from the snapshot.',
      ),
    },
    required: ['grossMonthly'],
  ),
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "PaycheckBreakdown",
          "title": "Where your paycheck goes",
          "grossMonthly": 9000,
          "taxRatePct": 24,
          "retirement401kPct": 5,
          "tone": "violet"
        }
      ]
    ''',
  ],
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    num readNum(String key, num fallback) => (data[key] as num?) ?? fallback;

    return Toned(
      tone: InstrumentTone.fromName(data['tone'] as String?),
      child: _PaycheckView(
        title: (data['title'] as String?) ?? 'Paycheck breakdown',
        gross: readNum('grossMonthly', 0).toDouble(),
        taxRate: readNum('taxRatePct', 22).toDouble().clamp(0, 50),
        initial401k: readNum('retirement401kPct', 5).toDouble().clamp(0, 50),
        source: data['source'] as String?,
        onApply: (summary) => itemContext.dispatchEvent(
          UserActionEvent(
            name: 'setPaycheckPlan',
            sourceComponentId: itemContext.id,
            context: {'summary': summary},
          ),
        ),
      ),
    );
  },
);

class _PaycheckView extends StatefulWidget {
  const _PaycheckView({
    required this.title,
    required this.gross,
    required this.taxRate,
    required this.initial401k,
    required this.source,
    required this.onApply,
  });

  final String title;
  final double gross;
  final double taxRate;
  final double initial401k;
  final String? source;
  final void Function(String summary) onApply;

  @override
  State<_PaycheckView> createState() => _PaycheckViewState();
}

class _PaycheckViewState extends State<_PaycheckView> {
  late double _pct = widget.initial401k;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final contribution = widget.gross * _pct / 100;
    final taxable = widget.gross - contribution;
    final tax = taxable * widget.taxRate / 100;
    final takeHome = taxable - tax;

    final status = _pct >= 10
        ? Status.good
        : (_pct >= 5 ? Status.warn : Status.bad);

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
              '${money(widget.gross)}/mo gross · ${widget.taxRate.round()}% tax',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                DonutChart(
                  segments: [
                    (
                      label: 'Take-home',
                      value: takeHome,
                      color: scheme.primary,
                    ),
                    (label: 'Tax', value: tax, color: scheme.error),
                    (
                      label: '401k',
                      value: contribution,
                      color: scheme.tertiary,
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Row(
                        color: scheme.primary,
                        label: 'Take-home',
                        amount: takeHome,
                      ),
                      _Row(color: scheme.error, label: 'Tax', amount: tax),
                      _Row(
                        color: scheme.tertiary,
                        label: '401k',
                        amount: contribution,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(
                status: status,
                text: 'Saving ${_pct.round()}% to retirement',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('401k contribution', style: theme.textTheme.labelLarge),
                const Spacer(),
                Text(
                  '${_pct.round()}%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: _pct,
              max: 30,
              divisions: 30,
              onChanged: (v) => setState(() => _pct = v),
            ),
            ApplyActionButton(
              label: 'Set my 401k contribution',
              onPressed: () => widget.onApply(
                'Contribute ${_pct.round()}% to 401k '
                '(${money(contribution)}/mo) — take-home ${money(takeHome)}/mo',
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
            '${money(amount)}/mo',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
