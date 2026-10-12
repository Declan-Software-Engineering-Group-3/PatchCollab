import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/screens/splash_screen.dart';
import '../../features/community/screens/community_screen.dart';
import '../providers/auth_state_provider.dart';

// signed in users go to community, everyone else starts at the splash screen.
// anonymous users count as signed out (the dev sign in in community is anonymous)
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authStateProvider, (previous, next) {
      final user = next.value;
      if (user != null && !user.isAnonymous) {
        // close the login / register screen that was pushed on top
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null && !user.isAnonymous) {
          return const CommunityScreen();
        }
        return const SplashScreen();
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => const SplashScreen(),
    );
  }
}
