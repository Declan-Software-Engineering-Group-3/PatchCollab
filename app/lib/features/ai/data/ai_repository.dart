import 'package:cloud_functions/cloud_functions.dart';

const aiRequestTypes = ['review', 'summarise', 'explain'];
const aiMaxPromptChars = 4000;

class AiResponse {
  final String requestId;
  final String response;
  final int remaining;

  const AiResponse({
    required this.requestId,
    required this.response,
    required this.remaining,
  });
}

class AiLimitReachedException implements Exception {
  const AiLimitReachedException();

  @override
  String toString() => "You've used all your PatchCollab AI requests for today.";
}

class AiRepository {
  final FirebaseFunctions _functions;

  AiRepository(this._functions);

  Future<AiResponse> ask({required String prompt, required String type}) async {
    try {
      final result = await _functions
          .httpsCallable('askPatchCollabAI')
          .call({'prompt': prompt, 'type': type});
      final data = Map<String, dynamic>.from(result.data as Map);
      return AiResponse(
        requestId: data['requestId'] as String,
        response: data['response'] as String,
        remaining: (data['remaining'] as num).toInt(),
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') throw const AiLimitReachedException();
      throw Exception(e.message ?? 'PatchCollab AI is unavailable right now.');
    }
  }
}
