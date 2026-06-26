import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/format.dart';
import 'package:genui_template/statuses.dart';
import 'package:genui_template/tones.dart';
import 'package:genui_template/widgets/apply_action_button.dart';
import 'package:genui_template/widgets/provenance_tag.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// NetWorthTracker — assets vs liabilities with the resulting net worth. The
/// user can tap to expand each side's breakdown.
final netWorthTracker = CatalogItem(
  name: 'NetWorthTracker',
  dataSchema: S.object(
    description:
        'Shows assets vs liabilities and the resulting net worth. Use for '
        '"what am I worth" / net-worth questions.',
    properties: {
      'title': S.string(description: 'Short heading.'),
      'assets': S.list(
        description: 'Things the user owns.',
        items: S.object(
          properties: {
            'name': S.string(description: 'e.g. "Savings", "Home".'),
            'amount': S.number(description: 'Value in dollars.'),
          },
          required: ['name', 'amount'],
        ),
      ),
      'liabilities': S.list(
        description: 'Things the user owes.',
        items: S.object(
          properties: {
            'name': S.string(description: 'e.g. "Mortgage", "Card".'),
            'amount': S.number(description: 'Balance owed in dollars.'),
          },
          required: ['name', 'amount'],
        ),
      ),
      'tone': S.string(
        description: 'Palette that fits the topic.',
        enumValues: InstrumentTone.names,
      ),
      'source': S.string(
        description: 'Set to "your linked accounts" when from the snapshot.',
      ),
    },
    required: ['assets', 'liabilities'],
  ),
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "NetWorthTracker",
          "title": "Your net worth",
          "assets": [
            {"name": "Cash savings", "amount": 18000},
            {"name": "Investments", "amount": 32000}
          ],
          "liabilities": [
            {"name": "Credit card", "amount": 6400},
            {"name": "Car loan", "amount": 9000}
          ],
          "tone": "teal",
          "source": "your linked accounts"
        }
      ]
    ''',
  ],
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    List<({String name, double amount})> parse(String key) =>
        ((data[key] as List?) ?? const [])
            .whereType<Map<String, Object?>>()
            .map(
              (m) => (
                name: (m['name'] as String?) ?? '',
                amount: ((m['amount'] as num?) ?? 0).toDouble(),
              ),
            )
            .toList();

    return Toned(
      tone: InstrumentTone.fromName(data['tone'] as String?),
      child: _NetWorthView(
        title: (data['title'] as String?) ?? 'Net worth',
        assets: parse('assets'),
        liabilities: parse('liabilities'),
        source: data['source'] as String?,
        onApply: (summary) => itemContext.dispatchEvent(
          UserActionEvent(
            name: 'trackNetWorth',
            sourceComponentId: itemContext.id,
            context: {'summary': summary},
          ),
        ),
      ),
    );
  },
);

class _NetWorthView extends StatefulWidget {
  const _NetWorthView({
    required this.title,
    required this.assets,
    required this.liabilities,
    required this.source,
    required this.onApply,
  });

  final String title;
  final List<({String name, double amount})> assets;
  final List<({String name, double amount})> liabilities;
  final String? source;
  final void Function(String summary) onApply;

  @override
  State<_NetWorthView> createState() => _NetWorthViewState();
}

class _NetWorthViewState extends State<_NetWorthView> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final totalAssets = widget.assets.fold<double>(0, (s, a) => s + a.amount);
    final totalLiab = widget.liabilities.fold<double>(
      0,
      (s, l) => s + l.amount,
    );
    final netWorth = totalAssets - totalLiab;
    final span = (totalAssets + totalLiab) == 0 ? 1.0 : totalAssets + totalLiab;
    final status = netWorth >= 0 ? Status.good : Status.bad;

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
            const SizedBox(height: 12),
            Text(
              money(netWorth),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: status.color,
              ),
            ),
            Text('net worth', style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            // Proportional assets vs liabilities bar.
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Expanded(
                    flex: (totalAssets / span * 1000).round().clamp(1, 1000),
                    child: Container(height: 14, color: scheme.primary),
                  ),
                  Expanded(
                    flex: (totalLiab / span * 1000).round().clamp(1, 1000),
                    child: Container(height: 14, color: scheme.error),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Legend(
                  color: scheme.primary,
                  label: 'Assets',
                  amount: totalAssets,
                ),
                const Spacer(),
                _Legend(
                  color: scheme.error,
                  label: 'Liabilities',
                  amount: totalLiab,
                ),
              ],
            ),
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Hide breakdown' : 'Show breakdown'),
            ),
            if (_expanded) ...[
              ...widget.assets.map(
                (a) => _LineItem(
                  name: a.name,
                  amount: a.amount,
                  positive: true,
                ),
              ),
              ...widget.liabilities.map(
                (l) =>
                    _LineItem(name: l.name, amount: l.amount, positive: false),
              ),
            ],
            ApplyActionButton(
              label: 'Track this net worth',
              onPressed: () => widget.onApply(
                'Track net worth of ${money(netWorth)} '
                '(${money(totalAssets)} assets, ${money(totalLiab)} debts)',
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

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.amount,
  });

  final Color color;
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label ${money(amount)}', style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem({
    required this.name,
    required this.amount,
    required this.positive,
  });

  final String name;
  final double amount;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(name, style: theme.textTheme.bodyMedium)),
          Text(
            '${positive ? '+' : '-'}${money(amount)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
