import 'package:flutter/material.dart';

class VoteButtons extends StatelessWidget {
  final int voteCount;
  final int? myVote;
  final void Function(int value) onVote;

  const VoteButtons({
    super.key,
    required this.voteCount,
    required this.myVote,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => onVote(1),
          icon: Icon(Icons.arrow_upward, color: myVote == 1 ? color : null),
        ),
        Text('$voteCount'),
        IconButton(
          onPressed: () => onVote(-1),
          icon: Icon(Icons.arrow_downward, color: myVote == -1 ? color : null),
        ),
      ],
    );
  }
}
