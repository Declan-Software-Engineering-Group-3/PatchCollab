import 'package:app/core/models/diff.dart';
import 'package:app/core/utils/diff_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const _diff = '''diff --git a/lib/a.dart b/lib/a.dart
index 111..222 100644
--- a/lib/a.dart
+++ b/lib/a.dart
@@ -1,3 +1,3 @@
 keep
-old
+new
 end
diff --git a/b.txt b/b.txt
new file mode 100644
--- /dev/null
+++ b/b.txt
@@ -0,0 +1,2 @@
+one
+two
''';

void main() {
  test('splits files and counts changes', () {
    final files = parseUnifiedDiff(_diff);
    expect(files.map((f) => f.path), ['lib/a.dart', 'b.txt']);
    expect(files[0].additions, 1);
    expect(files[0].deletions, 1);
    expect(files[1].additions, 2);
  });

  test('tracks line numbers on both sides', () {
    final lines = parseUnifiedDiff(_diff).first.lines;
    expect(lines.map((l) => l.type), [
      DiffLineType.hunk,
      DiffLineType.context,
      DiffLineType.removed,
      DiffLineType.added,
      DiffLineType.context,
    ]);
    expect(lines[2].oldNumber, 2);
    expect(lines[2].newNumber, isNull);
    expect(lines[3].newNumber, 2);
    expect(lines[4].oldNumber, 3);
    expect(lines[4].newNumber, 3);
  });

  test('parsePatch handles a bare GitHub patch with no file header', () {
    final file = parsePatch('x.py', '@@ -10,2 +10,2 @@\n a\n-b\n+c');
    expect(file.lines[1].oldNumber, 10);
    expect(file.lines.last.newNumber, 11);
  });

  test('empty input gives no files', () {
    expect(parseUnifiedDiff(''), isEmpty);
  });
}
