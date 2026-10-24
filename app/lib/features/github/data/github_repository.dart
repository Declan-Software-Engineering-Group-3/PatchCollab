import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../../core/models/diff.dart';
import '../../../core/utils/diff_parser.dart';
import 'github_repo_model.dart';

// Not a secret. Pass with --dart-define=GITHUB_CLIENT_ID=... when running.
const githubClientId = String.fromEnvironment('GITHUB_CLIENT_ID');
const _callbackScheme = 'patchcollab';
const _redirectUri = '$_callbackScheme://github-callback';

// No scope requested, which is read access to public repositories only.
// Asking for 'repo' would expose private repositories, which the ethics
// submission does not cover.
const _scope = '';

// listGitHubRepos pages are 50 repos each
const _maxRepoPages = 6;

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

  Future<String> connect() async {
    final code = await authorize();
    final data = await _call('exchangeGitHubCode', {
      'code': code,
      'redirectUri': _redirectUri,
    });
    return data['githubUsername'] as String;
  }

  /// All of the student's repositories, fetched a page at a time (50 each).
  Future<List<GithubRepo>> listRepos() async {
    final repos = <GithubRepo>[];
    for (var page = 1; page <= _maxRepoPages; page++) {
      final data = await _call('listGitHubRepos', {'page': page});
      repos.addAll(
        (data['repos'] as List).map(
          (r) => GithubRepo.fromMap(Map<String, dynamic>.from(r as Map)),
        ),
      );
      if (data['hasMore'] != true) break;
    }
    return repos;
  }

  /// The diff attached to a question. The function reads the question's own
  /// `diffRef`, using the author's token, so viewers don't need GitHub.
  Future<List<DiffFile>> fetchQuestionDiff(String questionId) async {
    final data = await _call('getGitHubDiff', {
      'target': 'question',
      'id': questionId,
    });
    return (data['files'] as List).map((f) {
      final file = Map<String, dynamic>.from(f as Map);
      final diff = parsePatch(
        file['filename'] as String,
        file['patch'] as String? ?? '',
      );
      return DiffFile(
        path: diff.path,
        lines: diff.lines,
        note: file['patchUnavailable'] == true
            ? 'No preview: GitHub did not provide a diff for this file (binary or too large).'
            : file['patchTruncated'] == true
            ? 'This file is long, so only the start of the diff is shown.'
            : null,
      );
    }).toList();
  }

  /// Revokes the token and clears the student's stored repository links.
  Future<void> disconnect() => _call('disconnectGitHub', {});

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> args,
  ) async {
    try {
      final result = await _functions.httpsCallable(name).call(args);
      return Map<String, dynamic>.from((result.data ?? {}) as Map);
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final reason = details is Map ? details['reason'] : null;
      if (reason == 'github-not-connected' ||
          reason == 'github-token-invalid') {
        throw const GithubNotConnectedException();
      }
      if (reason == 'github-rate-limited') {
        throw Exception(
          "GitHub's rate limit was reached. Try again in a few minutes.",
        );
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
