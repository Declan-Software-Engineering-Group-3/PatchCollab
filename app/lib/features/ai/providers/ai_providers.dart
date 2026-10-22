import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_repository.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(FirebaseFunctions.instanceFor(region: 'africa-south1'));
});

class AiState {
  final bool loading;
  final String? response;
  final String? error;
  final int? remaining;
  final bool limitReached;

  const AiState({
    this.loading = false,
    this.response,
    this.error,
    this.remaining,
    this.limitReached = false,
  });
}

class AiNotifier extends Notifier<AiState> {
  @override
  AiState build() => const AiState();

  Future<void> ask({required String prompt, required String type}) async {
    if (state.loading) return;
    // keep the last remaining count visible while the next request runs
    state = AiState(loading: true, remaining: state.remaining);
    try {
      final result = await ref
          .read(aiRepositoryProvider)
          .ask(prompt: prompt, type: type);
      state = AiState(response: result.response, remaining: result.remaining);
    } on AiLimitReachedException catch (e) {
      state = AiState(error: e.toString(), remaining: 0, limitReached: true);
    } catch (e) {
      state = AiState(
        error: e.toString().replaceFirst('Exception: ', ''),
        remaining: state.remaining,
      );
    }
  }
}

final aiProvider = NotifierProvider<AiNotifier, AiState>(AiNotifier.new);
