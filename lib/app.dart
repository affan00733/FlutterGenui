import 'package:flutter/material.dart';
import 'package:genui_template/home_page.dart';
import 'package:genui_template/theme_controller.dart';
import 'package:genui_template/tones.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The app chrome uses a fixed seed. Each generated instrument carries its
    // own `tone`, so re-colouring one tool never touches the window or the
    // tools already on screen. Light/dark is toggled from the header.
    final seed = InstrumentTone.fallback.seed;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Aria · Decision Studio',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: seed),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: seed,
              brightness: Brightness.dark,
            ),
          ),
          home: const HomePage(),
        );
      },
    );
  }
}
