import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/format.dart';
import 'package:genui_template/statuses.dart';
import 'package:genui_template/tones.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// ConfirmationCard — the "act" result. After the user taps an action button on
/// an instrument, the model responds with this to confirm what was done. It
/// closes the generate -> adapt -> ACT loop.
final confirmationCard = CatalogItem(
  name: 'ConfirmationCard',
  dataSchema: S.object(
    description:
        'A confirmation that an action the user took has been applied. Render '
        'this in response to an action interaction (e.g. "applyAllocation", '
        '"setGoal", "schedulePayment") to confirm what happened.',
    properties: {
      'title': S.string(description: 'e.g. "Plan applied".'),
      'message': S.string(description: 'One line on what was done.'),
      'items': S.list(
        description: 'Optional bullet summary of the action.',
        items: S.string(),
      ),
      'tone': S.string(
        description: 'Palette (usually emerald for success).',
        enumValues: InstrumentTone.names,
      ),
    },
    required: ['title'],
  ),
  exampleData: [
    () => r'''
      [
        {
          "id": "root",
          "component": "ConfirmationCard",
          "title": "Plan applied",
          "message": "We'll put your $6,400 toward the credit card.",
          "items": ["$6,400 to credit card", "Saves $3,951 in interest"],
          "tone": "emerald"
        }
      ]
    ''',
  ],
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    final items = (data['items'] as List?)
        ?.whereType<String>()
        .map(stripEmoji)
        .toList();
    final message = data['message'] as String?;

    return Toned(
      tone: InstrumentTone.fromName(data['tone'] as String?),
      child: _ConfirmationView(
        title: stripEmoji((data['title'] as String?) ?? 'Done'),
        message: message == null ? null : stripEmoji(message),
        items: items ?? const [],
      ),
    );
  },
);

class _ConfirmationView extends StatelessWidget {
  const _ConfirmationView({
    required this.title,
    required this.message,
    required this.items,
  });

  final String title;
  final String? message;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Status.good.icon, color: Status.good.color, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, style: theme.textTheme.bodyMedium),
            ],
            if (items.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check,
                        size: 16,
                        color: Status.good.color,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(item, style: theme.textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
