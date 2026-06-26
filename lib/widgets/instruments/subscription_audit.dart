import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/format.dart';
import 'package:genui_template/statuses.dart';
import 'package:genui_template/tones.dart';
import 'package:genui_template/widgets/apply_action_button.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// SubscriptionAudit — lists recurring subscriptions; the user toggles which to
/// cancel and sees the monthly + annualized savings update live.
final subscriptionAudit = CatalogItem(
  name: 'SubscriptionAudit',
  dataSchema: S.object(
    description:
        'Audits recurring subscriptions. Use for "where is my money leaking" / '
        '"review my subscriptions". The user toggles ones to cancel and sees '
        'the monthly and yearly savings. Provide realistic example subs if the '
        'user has not listed any.',
    properties: {
      'title': S.string(description: 'Short heading.'),
      'subscriptions': S.list(
        description: 'The recurring subscriptions.',
        items: S.object(
          properties: {
            'name': S.string(description: 'e.g. "Netflix".'),
            'monthly': S.number(description: 'Monthly cost in dollars.'),
          },
          required: ['name', 'monthly'],
        ),
      ),
      'tone': S.string(
        description: 'Palette that fits the topic.',
        enumValues: InstrumentTone.names,
      ),
    },
    required: ['subscriptions'],
  ),
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "SubscriptionAudit",
          "title": "Your monthly subscriptions",
          "subscriptions": [
            {"name": "Netflix", "monthly": 15.49},
            {"name": "Spotify", "monthly": 11.99},
            {"name": "Gym", "monthly": 45},
            {"name": "Cloud storage", "monthly": 9.99},
            {"name": "News+", "monthly": 12.99}
          ],
          "tone": "rose"
        }
      ]
    ''',
  ],
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    final subs = ((data['subscriptions'] as List?) ?? const [])
        .whereType<Map<String, Object?>>()
        .map(
          (m) => (
            name: (m['name'] as String?) ?? 'Subscription',
            monthly: ((m['monthly'] as num?) ?? 0).toDouble(),
          ),
        )
        .toList();

    return Toned(
      tone: InstrumentTone.fromName(data['tone'] as String?),
      child: _SubscriptionView(
        title: (data['title'] as String?) ?? 'Subscription audit',
        subs: subs,
        onApply: (summary) => itemContext.dispatchEvent(
          UserActionEvent(
            name: 'cancelSubscriptions',
            sourceComponentId: itemContext.id,
            context: {'summary': summary},
          ),
        ),
      ),
    );
  },
);

class _SubscriptionView extends StatefulWidget {
  const _SubscriptionView({
    required this.title,
    required this.subs,
    required this.onApply,
  });

  final String title;
  final List<({String name, double monthly})> subs;
  final void Function(String summary) onApply;

  @override
  State<_SubscriptionView> createState() => _SubscriptionViewState();
}

class _SubscriptionViewState extends State<_SubscriptionView> {
  final Set<int> _cancelled = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    var kept = 0.0;
    var saved = 0.0;
    for (var i = 0; i < widget.subs.length; i++) {
      if (_cancelled.contains(i)) {
        saved += widget.subs[i].monthly;
      } else {
        kept += widget.subs[i].monthly;
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
              '${money(kept)}/mo kept · ${money(kept * 12)}/yr',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < widget.subs.length; i++)
              _SubRow(
                name: widget.subs[i].name,
                monthly: widget.subs[i].monthly,
                cancelled: _cancelled.contains(i),
                onToggle: (cancel) => setState(() {
                  if (cancel) {
                    _cancelled.add(i);
                  } else {
                    _cancelled.remove(i);
                  }
                }),
              ),
            const SizedBox(height: 8),
            if (_cancelled.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(
                  status: Status.good,
                  text: 'Save ${money(saved)}/mo · ${money(saved * 12)}/yr',
                ),
              )
            else
              Text(
                "Toggle off any you don't need to see the savings.",
                style: theme.textTheme.bodySmall,
              ),
            ApplyActionButton(
              label: _cancelled.isEmpty
                  ? 'Keep all subscriptions'
                  : 'Cancel ${_cancelled.length} subscriptions',
              onPressed: () => widget.onApply(
                _cancelled.isEmpty
                    ? 'Keep all subscriptions (${money(kept)}/mo)'
                    : 'Cancel ${_cancelled.length} subscriptions, saving '
                          '${money(saved)}/mo (${money(saved * 12)}/yr)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubRow extends StatelessWidget {
  const _SubRow({
    required this.name,
    required this.monthly,
    required this.cancelled,
    required this.onToggle,
  });

  final String name;
  final double monthly;
  final bool cancelled;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: cancelled ? TextDecoration.lineThrough : null,
                color: cancelled ? theme.colorScheme.onSurfaceVariant : null,
              ),
            ),
          ),
          Text(
            '${money(monthly)}/mo',
            style: theme.textTheme.bodyMedium?.copyWith(
              decoration: cancelled ? TextDecoration.lineThrough : null,
              color: cancelled ? theme.colorScheme.onSurfaceVariant : null,
            ),
          ),
          Switch(value: !cancelled, onChanged: (keep) => onToggle(!keep)),
        ],
      ),
    );
  }
}
