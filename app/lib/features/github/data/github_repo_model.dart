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

  /// Linked repository fields as stored on a project or question.
  Map<String, dynamic> toLinkFields() => {
    'githubUrl': url,
    'githubOwner': owner,
    'githubRepo': name,
    'githubDefaultBranch': defaultBranch,
  };
}

/// What the picker hands back: a chosen repository, or null to unlink.
class RepoPickerResult {
  final GithubRepo? repo;

  const RepoPickerResult(this.repo);
}
