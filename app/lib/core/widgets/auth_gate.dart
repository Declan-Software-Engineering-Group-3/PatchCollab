import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/screens/splash_screen.dart';
import 'main_shell.dart';
import '../providers/auth_state_provider.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authStateProvider, (previous, next) {
      final user = next.value;
      if (user != null && !user.isAnonymous) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null && !user.isAnonymous) {
          return const MainShell();
        }
        return const SplashScreen();
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => const SplashScreen(),
    );
  }
}
