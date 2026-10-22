import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../../core/models/diff.dart';
import '../../../core/utils/diff_parser.dart';
import 'diff_source.dart';
import 'github_repo_model.dart';

// Not a secret. Pass with --dart-define=GITHUB_CLIENT_ID=... when running.
const githubClientId = String.fromEnvironment('GITHUB_CLIENT_ID');
const _callbackScheme = 'patchcollab';
const _redirectUri = '$_callbackScheme://github-callback';

// No scope requested, which is read access to public repositories only.
// Asking for 'repo' would expose private repositories, which the ethics
// submission does not cover.
const _scope = '';

class GithubNotConnectedException implements Exception {
  const GithubNotConnectedException();

  @override
  String toString() => 'Connect your GitHub account first.';
}

class GithubRepository {
  final FirebaseFunctions _functions;

  GithubRepository(this._functions);

  /// Opens the GitHub consent screen and returns the authorisation code.
  /// The code is then exchanged for a token on the server (task 52), so the
  /// token never touches the client.
  Future<String> authorize() async {
    if (githubClientId.isEmpty) {
      throw Exception('GITHUB_CLIENT_ID was not set for this build.');
    }
    final state = _randomState();
    final url = Uri.https('github.com', '/login/oauth/authorize', {
      'client_id': githubClientId,
      'redirect_uri': _redirectUri,
      'state': state,
      if (_scope.isNotEmpty) 'scope': _scope,
    });

    final result = await FlutterWebAuth2.authenticate(
      url: url.toString(),
      callbackUrlScheme: _callbackScheme,
    );

    final params = Uri.parse(result).queryParameters;
    if (params['error'] != null) {
      throw Exception('GitHub sign in was cancelled or denied.');
    }
    if (params['state'] != state) {
      throw Exception('GitHub sign in could not be verified. Try again.');
    }
    final code = params['code'];
    if (code == null) throw Exception('GitHub did not return a code.');
    return code;
  }

  Future<void> connect() async {
    final code = await authorize();
    await _call('exchangeGithubCode', {'code': code});
  }

  Future<List<GithubRepo>> listRepos() async {
    final data = await _call('listGithubRepos', {});
    return (data['repos'] as List)
        .map((r) => GithubRepo.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<List<DiffFile>> fetchDiff({
    required String owner,
    required String repo,
    required DiffSource source,
  }) async {
    final data = await _call('getGithubDiff', {
      'owner': owner,
      'repo': repo,
      'kind': source.kind.name,
      'value': source.value,
    });
    return (data['files'] as List).map((f) {
      final file = Map<String, dynamic>.from(f as Map);
      // GitHub leaves patch out for binary or very large files
      return parsePatch(file['path'] as String, file['patch'] as String? ?? '');
    }).toList();
  }

  /// Revokes the token and clears the student's stored repository links.
  Future<void> disconnect() => _call('disconnectGithub', {});

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> args,
  ) async {
    try {
      final result = await _functions.httpsCallable(name).call(args);
      return Map<String, dynamic>.from((result.data ?? {}) as Map);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        throw const GithubNotConnectedException();
      }
      throw Exception(e.message ?? 'GitHub request failed (${e.code}).');
    }
  }

  String _randomState() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
