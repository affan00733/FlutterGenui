import 'package:flutter/material.dart';

/// A semantic state used for *value-driven* colour inside instruments — it
/// shifts as the user interacts (e.g. a slider) to depict whether the current
/// choice is good, borderline, or bad. This is independent of the topic `tone`:
/// tone colours the instrument by subject, status colours feedback by outcome.
enum Status {
  good(Color(0xFF2E7D32), Icons.check_circle, 'Good'),
  warn(Color(0xFFF57C00), Icons.info_outline, 'Caution'),
  bad(Color(0xFFC62828), Icons.warning_amber_rounded, 'Risk');

  const Status(this.color, this.icon, this.label);

  final Color color;
  final IconData icon;
  final String label;
}

/// A pill that depicts a [Status] with its semantic colour and icon. Rebuilds
/// live as the status changes, so the colour visibly moves good -> bad.
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, required this.text, super.key});

  final Status status;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 16, color: status.color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: status.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
