import 'package:flutter/material.dart';

/// App-wide light/dark mode, toggled from the header. `MainApp` listens to this
/// and rebuilds its theme; the header rebuilds its icon on toggle.
final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
  ThemeMode.light,
);

void toggleThemeMode() {
  themeMode.value = themeMode.value == ThemeMode.dark
      ? ThemeMode.light
      : ThemeMode.dark;
}
