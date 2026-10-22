enum DiffLineType { context, added, removed, hunk }

class DiffLine {
  final DiffLineType type;
  final String text;

  /// Line number in the old file, null for added lines and hunk headers.
  final int? oldNumber;

  /// Line number in the new file, null for removed lines and hunk headers.
  final int? newNumber;

  const DiffLine({
    required this.type,
    required this.text,
    this.oldNumber,
    this.newNumber,
  });
}

class DiffFile {
  final String path;
  final List<DiffLine> lines;

  const DiffFile({required this.path, required this.lines});

  int get additions => lines.where((l) => l.type == DiffLineType.added).length;
  int get deletions =>
      lines.where((l) => l.type == DiffLineType.removed).length;
}
