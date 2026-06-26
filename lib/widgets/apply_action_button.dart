import 'package:flutter/material.dart';

/// A consistent full-width "act" button placed at the bottom of actionable
/// instruments. Tapping it sends the user's choice back to the AI, which
/// confirms with a ConfirmationCard — closing the generate/adapt/act loop.
class ApplyActionButton extends StatelessWidget {
  const ApplyActionButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.check),
          label: Text(label),
        ),
      ),
    );
  }
}
