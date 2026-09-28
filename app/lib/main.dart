import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: PatchCollabApp()));
}

class PatchCollabApp extends StatelessWidget {
  const PatchCollabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PatchCollab',
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(
        body: Center(child: Text('PatchCollab')),
      ),
    );
  }
}
