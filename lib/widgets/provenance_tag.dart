import 'package:flutter/material.dart';

/// A subtle "from your accounts" tag shown on instruments whose figures are
/// pre-filled from the user's real data. It makes the key differentiator
/// visible: the numbers are grounded in a source of truth, not invented by the
/// model the way a free-form chat artifact would.
class ProvenanceTag extends StatelessWidget {
  const ProvenanceTag({required this.source, super.key});

  final String source;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline, size: 13, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          'From $source',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
