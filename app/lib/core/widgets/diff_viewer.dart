import 'package:flutter/material.dart';

import '../models/diff.dart';
import '../utils/diff_parser.dart';

/// Called when a student taps a line. Used to anchor an answer to a line.
/// [newSide] is false for removed lines, which only exist in the old file.
typedef DiffLineTap = void Function(
  DiffFile file,
  DiffLine line, {
  required bool newSide,
});

/// A line anchor to highlight, as stored on an answer.
class DiffAnchor {
  final String path;
  final int line;
  final bool newSide;

  const DiffAnchor({
    required this.path,
    required this.line,
    this.newSide = true,
  });
}

/// Unified diff viewer with added/removed styling, per-file collapse and
/// long-file truncation.
///
/// Give it either a full unified diff with [DiffViewer.new] or already split
/// files with [DiffViewer.files].
class DiffViewer extends StatelessWidget {
  final List<DiffFile> files;
  final DiffLineTap? onLineTap;
  final DiffAnchor? highlight;

  /// Files longer than this show a "show all" button instead of every line.
  final int maxLines;

  DiffViewer({
    super.key,
    required String diff,
    this.onLineTap,
    this.highlight,
    this.maxLines = 300,
  }) : files = parseUnifiedDiff(diff);

  const DiffViewer.files({
    super.key,
    required this.files,
    this.onLineTap,
    this.highlight,
    this.maxLines = 300,
  });

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No changes in this diff.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final file in files)
          _DiffFileCard(
            file: file,
            onLineTap: onLineTap,
            highlight: highlight,
            maxLines: maxLines,
          ),
      ],
    );
  }
}

class _DiffFileCard extends StatefulWidget {
  final DiffFile file;
  final DiffLineTap? onLineTap;
  final DiffAnchor? highlight;
  final int maxLines;

  const _DiffFileCard({
    required this.file,
    required this.onLineTap,
    required this.highlight,
    required this.maxLines,
  });

  @override
  State<_DiffFileCard> createState() => _DiffFileCardState();
}

class _DiffFileCardState extends State<_DiffFileCard> {
  late bool _expanded = true;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final truncated = !_showAll && file.lines.length > widget.maxLines;
    final visible = truncated
        ? file.lines.take(widget.maxLines).toList()
        : file.lines;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(_expanded ? Icons.expand_more : Icons.chevron_right),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      file.path,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '+${file.additions}',
                    style: const TextStyle(color: _addedText),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '-${file.deletions}',
                    style: const TextStyle(color: _removedText),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            if (file.note != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  file.note!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final line in visible)
                      _DiffLineRow(
                        line: line,
                        highlighted: _isHighlighted(line),
                        onTap:
                            widget.onLineTap == null ||
                                line.type == DiffLineType.hunk
                            ? null
                            : () => widget.onLineTap!(
                                file,
                                line,
                                newSide: line.type != DiffLineType.removed,
                              ),
                      ),
                  ],
                ),
              ),
            ),
            if (truncated)
              TextButton(
                onPressed: () => setState(() => _showAll = true),
                child: Text(
                  'Show all ${file.lines.length} lines '
                  '(${file.lines.length - widget.maxLines} hidden)',
                ),
              ),
          ],
        ],
      ),
    );
  }

  bool _isHighlighted(DiffLine line) {
    final h = widget.highlight;
    if (h == null || h.path != widget.file.path) return false;
    return h.newSide ? line.newNumber == h.line : line.oldNumber == h.line;
  }
}

const _addedText = Color(0xFF3FB950);
const _removedText = Color(0xFFF85149);

class _DiffLineRow extends StatelessWidget {
  final DiffLine line;
  final bool highlighted;
  final VoidCallback? onTap;

  const _DiffLineRow({
    required this.line,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (background, marker) = switch (line.type) {
      DiffLineType.added => (_addedText.withValues(alpha: 0.15), '+'),
      DiffLineType.removed => (_removedText.withValues(alpha: 0.15), '-'),
      DiffLineType.hunk => (Colors.white.withValues(alpha: 0.06), ''),
      DiffLineType.context => (Colors.transparent, ' '),
    };
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 12.5);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: highlighted
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
            : background,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        child: Row(
          children: [
            _Gutter(line.oldNumber),
            _Gutter(line.newNumber),
            Text(
              line.type == DiffLineType.hunk
                  ? line.text
                  : '$marker${line.text}',
              style: mono.copyWith(
                color: line.type == DiffLineType.hunk ? Colors.white60 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Gutter extends StatelessWidget {
  final int? number;

  const _Gutter(this.number);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: Text(
        number?.toString() ?? '',
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: Colors.white38,
        ),
      ),
    );
  }
}
