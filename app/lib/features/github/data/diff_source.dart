/// What a review request points at: a commit, a branch comparison or a pull
/// request in the linked repository.
enum DiffKind { commit, compare, pull }

class DiffSource {
  final DiffKind kind;

  /// Commit sha, "base...head" for a comparison, or the pull request number.
  final String value;

  const DiffSource(this.kind, this.value);

  String get label => switch (kind) {
    DiffKind.commit =>
      'Commit ${value.length > 7 ? value.substring(0, 7) : value}',
    DiffKind.compare => 'Compare $value',
    DiffKind.pull => 'Pull request #$value',
  };

  /// The `diffRef` map stored on a question. The rules accept exactly these
  /// shapes: {kind, sha}, {kind, base, head} or {kind, number}.
  Map<String, dynamic> toDiffRef() {
    final text = value.trim();
    switch (kind) {
      case DiffKind.commit:
        return {'kind': 'commit', 'sha': text};
      case DiffKind.compare:
        final parts = text.split('...');
        return {'kind': 'compare', 'base': parts.first, 'head': parts.last};
      case DiffKind.pull:
        return {'kind': 'pull', 'number': int.parse(text)};
    }
  }

  static DiffSource? fromDiffRef(Object? data) {
    if (data is! Map) return null;
    switch (data['kind']) {
      case 'commit':
        return DiffSource(DiffKind.commit, data['sha'] as String);
      case 'compare':
        return DiffSource(
          DiffKind.compare,
          '${data['base']}...${data['head']}',
        );
      case 'pull':
        return DiffSource(DiffKind.pull, '${data['number']}');
    }
    return null;
  }

  /// Returns an error message, or null when [value] fits [kind].
  static String? validate(DiffKind kind, String value) {
    final text = value.trim();
    switch (kind) {
      case DiffKind.commit:
        return RegExp(r'^[0-9a-fA-F]{7,40}$').hasMatch(text)
            ? null
            : 'Enter a commit sha (7 to 40 hex characters)';
      case DiffKind.compare:
        return RegExp(r'^[^\s.]+(\.[^\s.]+)*\.\.\.[^\s]+$').hasMatch(text)
            ? null
            : 'Use base...head, for example main...my-branch';
      case DiffKind.pull:
        return RegExp(r'^\d+$').hasMatch(text)
            ? null
            : 'Enter the pull request number';
    }
  }
}
