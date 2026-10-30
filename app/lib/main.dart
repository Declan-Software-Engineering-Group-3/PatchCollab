import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'core/widgets/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: PatchCollabApp()));
}

class PatchCollabApp extends StatelessWidget {
  const PatchCollabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PatchCollab',
      theme: ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF001B1A),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF00D6C9),
    brightness: Brightness.dark,
  ).copyWith(
    surface: const Color(0xFF001B1A),
    primaryContainer: const Color(0xFF064C48),
    surfaceContainerHighest: const Color(0xFF153331),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF001B1A),
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  inputDecorationTheme: const InputDecorationTheme(
    filled: true,
    fillColor: Color(0xFF153331),
    hintStyle: TextStyle(color: Colors.white54),
    border: OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF28514E)),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF28514E)),
    ),
  ),
),
      // TODO: replace with the real navigation shell, community is the only screen for now
      home: const AuthGate(),
    );
  }
}
