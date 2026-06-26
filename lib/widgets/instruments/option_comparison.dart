import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_template/tones.dart';
import 'package:genui_template/widgets/apply_action_button.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// OptionComparison — an interactive side-by-side comparison of 2-4 options
/// (accounts, funds, loans). The model fills each option's metrics and marks a
/// recommended one; the user taps a card to select it.
final optionComparison = CatalogItem(
  name: 'OptionComparison',
  dataSchema: S.object(
    description:
        'A side-by-side comparison of 2 to 4 financial options (e.g. a HYSA '
        'vs an index fund, or loan offers). Use when the user wants to weigh '
        'distinct products against each other.',
    properties: {
      'title': S.string(description: 'Short heading for the comparison.'),
      'options': S.list(
        description: '2 to 4 options to compare.',
        items: S.object(
          properties: {
            'name': S.string(description: 'Option name.'),
            'metrics': S.list(
              description: 'Comparable attributes shown as label/value rows.',
              items: S.object(
                properties: {
                  'label': S.string(description: 'e.g. "APY", "Fee", "Risk".'),
                  'value': S.string(description: r'e.g. "4.50%", "$0", "Low".'),
                },
                required: ['label', 'value'],
              ),
            ),
            'tag': S.string(
              description: 'Optional short tag, e.g. "Best for safety".',
            ),
            'highlight': S.boolean(
              description: 'True for the single recommended option.',
            ),
          },
          required: ['name'],
        ),
      ),
      'tone': S.string(
        description: 'Palette that fits the topic. One of the allowed names.',
        enumValues: InstrumentTone.names,
      ),
    },
    required: ['title', 'options'],
  ),
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "OptionComparison",
          "title": "Where should your emergency fund live?",
          "options": [
            {
              "name": "High-yield savings",
              "tag": "Best for safety",
              "highlight": true,
              "metrics": [
                {"label": "APY", "value": "4.50%"},
                {"label": "Risk", "value": "None"},
                {"label": "Access", "value": "Instant"}
              ]
            },
            {
              "name": "S&P 500 index fund",
              "metrics": [
                {"label": "Return", "value": "~7%/yr"},
                {"label": "Risk", "value": "High"},
                {"label": "Access", "value": "1-3 days"}
              ]
            }
          ]
        }
      ]
    ''',
    () => r'''
      [
        {
          "id": "root",
          "component": "OptionComparison",
          "title": "Which loan offer is cheaper?",
          "options": [
            {
              "name": "Bank A",
              "tag": "Lowest total cost",
              "highlight": true,
              "metrics": [
                {"label": "APR", "value": "5.9%"},
                {"label": "Term", "value": "5 yr"},
                {"label": "Fees", "value": "$0"}
              ]
            },
            {
              "name": "Bank B",
              "metrics": [
                {"label": "APR", "value": "6.4%"},
                {"label": "Term", "value": "5 yr"},
                {"label": "Fees", "value": "$200"}
              ]
            }
          ]
        }
      ]
    ''',
  ],
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    final rawOptions = (data['options'] as List?) ?? const [];
    final options = rawOptions
        .whereType<Map<String, Object?>>()
        .map(_ComparisonOption.fromMap)
        .toList();

    return Toned(
      tone: InstrumentTone.fromName(data['tone'] as String?),
      child: _OptionComparisonView(
        title: (data['title'] as String?) ?? 'Compare your options',
        options: options,
        onApply: (summary) => itemContext.dispatchEvent(
          UserActionEvent(
            name: 'chooseOption',
            sourceComponentId: itemContext.id,
            context: {'summary': summary},
          ),
        ),
      ),
    );
  },
);

class _ComparisonOption {
  const _ComparisonOption({
    required this.name,
    required this.metrics,
    required this.tag,
    required this.highlight,
  });

  factory _ComparisonOption.fromMap(Map<String, Object?> map) {
    final metrics = ((map['metrics'] as List?) ?? const [])
        .whereType<Map<String, Object?>>()
        .map(
          (m) => (
            label: (m['label'] as String?) ?? '',
            value: (m['value'] as String?) ?? '',
          ),
        )
        .toList();
    return _ComparisonOption(
      name: (map['name'] as String?) ?? 'Option',
      metrics: metrics,
      tag: map['tag'] as String?,
      highlight: (map['highlight'] as bool?) ?? false,
    );
  }

  final String name;
  final List<({String label, String value})> metrics;
  final String? tag;
  final bool highlight;
}

class _OptionComparisonView extends StatefulWidget {
  const _OptionComparisonView({
    required this.title,
    required this.options,
    required this.onApply,
  });

  final String title;
  final List<_ComparisonOption> options;
  final void Function(String summary) onApply;

  @override
  State<_OptionComparisonView> createState() => _OptionComparisonViewState();
}

class _OptionComparisonViewState extends State<_OptionComparisonView> {
  late int _selected = () {
    final i = widget.options.indexWhere((o) => o.highlight);
    return i >= 0 ? i : 0;
  }();

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
            Text(widget.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < widget.options.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: _OptionCard(
                        option: widget.options[i],
                        selected: i == _selected,
                        onTap: () => setState(() => _selected = i),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.options.isNotEmpty)
              ApplyActionButton(
                label: 'Choose ${widget.options[_selected].name}',
                onPressed: () => widget.onApply(
                  'Go with ${widget.options[_selected].name}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ComparisonOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (option.highlight)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  option.tag ?? 'Recommended',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimary,
                  ),
                ),
              )
            else if (option.tag != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  option.tag!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            Text(
              option.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            for (final metric in option.metrics)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        metric.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      metric.value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
