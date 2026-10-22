import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/diff.dart';
import '../data/diff_source.dart';
import '../data/github_repo_model.dart';
import '../data/github_repository.dart';

final githubRepositoryProvider = Provider<GithubRepository>((ref) {
  return GithubRepository(
    FirebaseFunctions.instanceFor(region: 'africa-south1'),
  );
});

/// Throws GithubNotConnectedException when the student has not connected yet.
final githubReposProvider = FutureProvider.autoDispose<List<GithubRepo>>((ref) {
  return ref.watch(githubRepositoryProvider).listRepos();
});

final githubDiffProvider = FutureProvider.autoDispose
    .family<List<DiffFile>, (String, String, DiffKind, String)>((ref, key) {
      final (owner, repo, kind, value) = key;
      return ref
          .watch(githubRepositoryProvider)
          .fetchDiff(owner: owner, repo: repo, source: DiffSource(kind, value));
    });
