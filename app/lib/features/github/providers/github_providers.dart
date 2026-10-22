import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
