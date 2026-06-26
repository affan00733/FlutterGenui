import 'package:flutter/material.dart';
import 'package:genui_template/app.dart';
import 'package:genui_template/data/profile_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loads the profile from Supabase if configured, else keeps the mock.
  await ProfileRepository.init();
  runApp(const MainApp());
}
