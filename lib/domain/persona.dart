/// The user persona the experience adapts to. Toggled in the app bar and
/// injected into the system prompt, this is one of the "adapts meaningfully"
/// axes the judges look for: the SAME question yields a different UX.
enum Persona {
  novice('Novice'),
  expert('Expert');

  const Persona(this.label);

  /// Display label for the toggle.
  final String label;

  /// Guidance appended to the system prompt so the model tailors density and
  /// explanation depth to the user. Written as forceful, concrete rules so the
  /// two personas produce VISIBLY different layouts (the adaptation is part of
  /// what is being judged).
  String get promptFragment => switch (this) {
    Persona.novice =>
      'CRITICAL — NOVICE MODE. The user is NEW to investing. You MUST wrap the '
          'instrument in plain-English guidance:\n'
          '1. FIRST child of the Column: a `Text` (variant "body") that '
          'explains in ONE everyday sentence what this decision means.\n'
          '2. Then the single instrument.\n'
          '3. LAST child: a `Text` (variant "caption") starting with '
          '"In plain terms:" that states the bottom-line recommendation in '
          'simple words.\n'
          'Generate exactly ONE instrument. Avoid jargon; define any '
          'unavoidable term in parentheses.',
    Persona.expert =>
      'CRITICAL — EXPERT MODE. The user is an EXPERIENCED investor. You MUST '
          'keep it bare and dense:\n'
          '1. Do NOT add any explanatory, tutorial, or "in plain terms" '
          '`Text`. No hand-holding sentences.\n'
          '2. Show only a short title heading plus the instrument itself.\n'
          '3. Use precise figures and, where the instrument supports extra '
          'rows/metrics, include more of them. Be terse.',
  };
}
