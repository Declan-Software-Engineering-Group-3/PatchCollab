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

  Map<String, dynamic> toMap() => {'kind': kind.name, 'value': value};

  static DiffSource? fromFields(String? kind, String? value) {
    if (kind == null || value == null) return null;
    for (final k in DiffKind.values) {
      if (k.name == kind) return DiffSource(k, value);
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
