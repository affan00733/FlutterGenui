import 'package:flutter/material.dart';

/// A curated palette an instrument can be rendered in. The AI picks a `tone`
/// per instrument based on the topic, so colour varies automatically across
/// cases — without the user ever specifying a colour. Eight palettes plus live
/// parameters yield hundreds of distinct-looking generated tools from a small,
/// clean catalog.
enum InstrumentTone {
  emerald(Color(0xFF0F766E)),
  ocean(Color(0xFF1E88E5)),
  violet(Color(0xFF7B1FA2)),
  amber(Color(0xFFF57C00)),
  rose(Color(0xFFC2185B)),
  indigo(Color(0xFF3949AB)),
  teal(Color(0xFF00897B)),
  slate(Color(0xFF475569));

  const InstrumentTone(this.seed);

  /// The seed colour this palette is built from.
  final Color seed;

  /// The default palette (also used by the app chrome).
  static const InstrumentTone fallback = InstrumentTone.emerald;

  /// All palette names, for the instrument schemas' `tone` enum.
  static List<String> get names => values.map((t) => t.name).toList();

  /// Resolves a tone by name, falling back to [fallback] if unknown/null.
  static InstrumentTone fromName(String? name) => values.firstWhere(
    (t) => t.name == name,
    orElse: () => fallback,
  );
}

/// Renders [child] in the given [tone] by scoping a Material [Theme] to it, so
/// only this instrument is recoloured — never the rest of the page.
class Toned extends StatelessWidget {
  const Toned({required this.tone, required this.child, super.key});

  final InstrumentTone tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: tone.seed,
          brightness: Theme.of(context).brightness,
        ),
      ),
      child: child,
    );
  }
}
