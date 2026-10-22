import '../models/diff.dart';

final _hunkHeader = RegExp(r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@');
final _gitHeader = RegExp(r'^diff --git a/(.+) b/(.+)$');

/// Parses a full unified diff (`git diff` / GitHub `.diff` output) into files.
List<DiffFile> parseUnifiedDiff(String diff) {
  final files = <DiffFile>[];
  String? path;
  var patch = <String>[];

  void flush() {
    if (path != null) {
      files.add(parsePatch(path,patch.join('\n')));
    }
    patch = [];
  }

  for (final line in diff.split('\n')) {
    final header = _gitHeader.firstMatch(line);
    if (header != null) {
      flush();
      path = header.group(2);
    } else if (path != null) {
      patch.add(line);
    }
  }
  flush();
  return files;
}

/// Parses the hunks of a single file's patch. This is also the shape the
/// GitHub API returns per file, where there is no `diff --git` header.
DiffFile parsePatch(String path, String patch) {
  final lines = <DiffLine>[];
  var oldNo = 0;
  var newNo = 0;
  var inHunk = false;

  for (final raw in patch.split('\n')) {
    final hunk = _hunkHeader.firstMatch(raw);
    if (hunk != null) {
      oldNo = int.parse(hunk.group(1)!);
      newNo = int.parse(hunk.group(2)!);
      inHunk = true;
      lines.add(DiffLine(type: DiffLineType.hunk, text: raw));
      continue;
    }
    // skips index, ---, +++ and mode lines before the first hunk
    if (!inHunk) continue;

    if (raw.startsWith('+')) {
      lines.add(
        DiffLine(
          type: DiffLineType.added,
          text: raw.substring(1),
          newNumber: newNo++,
        ),
      );
    } else if (raw.startsWith('-')) {
      lines.add(
        DiffLine(
          type: DiffLineType.removed,
          text: raw.substring(1),
          oldNumber: oldNo++,
        ),
      );
    } else if (raw.startsWith(r'\')) {
      // "\ No newline at end of file"
      continue;
    } else {
      lines.add(
        DiffLine(
          type: DiffLineType.context,
          text: raw.isEmpty ? '' : raw.substring(1),
          oldNumber: oldNo++,
          newNumber: newNo++,
        ),
      );
    }
  }

  // split leaves one empty context line after the trailing newline
  if (lines.isNotEmpty &&
      lines.last.type == DiffLineType.context &&
      lines.last.text.isEmpty &&
      patch.endsWith('\n')) {
    lines.removeLast();
  }
  return DiffFile(path: path, lines: lines);
}
