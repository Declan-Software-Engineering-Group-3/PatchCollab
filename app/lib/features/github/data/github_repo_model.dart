import 'package:cloud_firestore/cloud_firestore.dart';

class GithubRepo {
  final String owner;
  final String name;
  final String defaultBranch;
  final bool isPrivate;

  const GithubRepo({
    required this.owner,
    required this.name,
    required this.defaultBranch,
    this.isPrivate = false,
  });

  String get fullName => '$owner/$name';
  String get url => 'https://github.com/$owner/$name';

  factory GithubRepo.fromMap(Map<String, dynamic> data) {
    return GithubRepo(
      owner: data['owner'] as String,
      name: data['name'] as String,
      defaultBranch: data['defaultBranch'] as String? ?? 'main',
      isPrivate: data['private'] as bool? ?? false,
    );
  }

  /// The `linkedRepo` map stored on a project or question. The rules accept
  /// exactly these four keys.
  Map<String, dynamic> toLinkedRepo() => {
    'owner': owner,
    'name': name,
    'defaultBranch': defaultBranch,
    'linkedAt': FieldValue.serverTimestamp(),
  };

  static GithubRepo? fromLinkedRepo(Object? data) {
    if (data is! Map) return null;
    return GithubRepo(
      owner: data['owner'] as String,
      name: data['name'] as String,
      defaultBranch: data['defaultBranch'] as String? ?? 'main',
    );
  }
}

/// What the picker hands back: a chosen repository, or null to unlink.
class RepoPickerResult {
  final GithubRepo? repo;

  const RepoPickerResult(this.repo);
}
