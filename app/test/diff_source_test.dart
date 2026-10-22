import 'package:app/features/github/data/diff_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validates each kind', () {
    expect(DiffSource.validate(DiffKind.commit, 'a1b2c3d'), isNull);
    expect(DiffSource.validate(DiffKind.commit, 'xyz'), isNotNull);
    expect(DiffSource.validate(DiffKind.compare, 'main...feature/x'), isNull);
    expect(DiffSource.validate(DiffKind.compare, 'main'), isNotNull);
    expect(DiffSource.validate(DiffKind.pull, '12'), isNull);
    expect(DiffSource.validate(DiffKind.pull, '#12'), isNotNull);
  });

  test('round trips through stored fields', () {
    final source = DiffSource.fromFields('pull', '7');
    expect(source?.kind, DiffKind.pull);
    expect(source?.value, '7');
    expect(DiffSource.fromFields(null, '7'), isNull);
    expect(DiffSource.fromFields('bogus', '7'), isNull);
  });
}
