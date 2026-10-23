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

  test('builds the diffRef shapes the rules accept', () {
    expect(const DiffSource(DiffKind.commit, ' a1b2c3d ').toDiffRef(), {
      'kind': 'commit',
      'sha': 'a1b2c3d',
    });
    expect(const DiffSource(DiffKind.compare, 'main...feat/x').toDiffRef(), {
      'kind': 'compare',
      'base': 'main',
      'head': 'feat/x',
    });
    expect(const DiffSource(DiffKind.pull, '12').toDiffRef(), {
      'kind': 'pull',
      'number': 12,
    });
  });

  test('reads a stored diffRef back', () {
    final source = DiffSource.fromDiffRef({
      'kind': 'compare',
      'base': 'main',
      'head': 'dev',
    });
    expect(source?.kind, DiffKind.compare);
    expect(source?.value, 'main...dev');
    expect(DiffSource.fromDiffRef({'kind': 'pull', 'number': 7})?.value, '7');
    expect(DiffSource.fromDiffRef(null), isNull);
    expect(DiffSource.fromDiffRef({'kind': 'bogus'}), isNull);
  });
}
