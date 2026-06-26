/// Small formatting helpers shared by the financial instruments. Kept
/// dependency-free (no intl) so the widgets stay self-contained.
library;

/// Formats a number as whole-dollar USD with thousands separators, e.g.
/// `1234567` -> `$1,234,567`.
String money(num value) {
  final negative = value < 0;
  final digits = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}\$$buffer';
}

/// Formats a percentage value, e.g. `7.5` -> `7.5%` (trims trailing `.0`).
String pct(num value) {
  final s = value.toStringAsFixed(1);
  return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}%';
}

final _emoji = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{2300}-\u{23FF}'
  r'\u{2B00}-\u{2BFF}\u{FE0F}\u{1F1E6}-\u{1F1FF}\u{200D}]',
  unicode: true,
);

/// Strips emoji from model-generated text. They don't render on web (the
/// "missing Noto fonts" warning) and look broken — a safety net on top of
/// the prompt. Leaves arrows, dashes, and bullets intact.
String stripEmoji(String text) =>
    text.replaceAll(_emoji, '').replaceAll(RegExp(' {2,}'), ' ').trim();
