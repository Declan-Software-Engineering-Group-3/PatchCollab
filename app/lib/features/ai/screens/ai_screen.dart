import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../community/community_theme.dart';
import '../data/ai_repository.dart';
import '../providers/ai_providers.dart';

const _typeLabels = {
  'review': 'Review code',
  'summarise': 'Summarise',
  'explain': 'Explain',
};

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  final _promptController = TextEditingController();
  String _type = aiRequestTypes.first;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _submit() {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;
    FocusScope.of(context).unfocus();
    ref.read(aiProvider.notifier).ask(prompt: prompt, type: _type);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiProvider);
    final theme = Theme.of(context);

    return Theme(
      data: communityTheme,
      child: Scaffold(
        appBar: AppBar(title: const Text('PatchCollab AI')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: [
                for (final type in aiRequestTypes)
                  ButtonSegment(value: type, label: Text(_typeLabels[type]!)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _promptController,
              minLines: 6,
              maxLines: 14,
              maxLength: aiMaxPromptChars,
              enabled: !state.loading,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: 'Paste code or ask a question',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: state.loading || state.limitReached ? null : _submit,
              icon: const Icon(Icons.auto_awesome),
              label: Text(state.loading ? 'Thinking...' : 'Ask PatchCollab AI'),
            ),
            if (state.remaining != null) ...[
              const SizedBox(height: 8),
              Text(
                '${state.remaining} request${state.remaining == 1 ? '' : 's'} left today',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            if (state.loading)
              const Center(child: CircularProgressIndicator())
            else if (state.error != null)
              Text(
                state.error!,
                style: TextStyle(color: theme.colorScheme.error),
              )
            else if (state.response != null)
              _ResponseCard(text: state.response!),
          ],
        ),
      ),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  final String text;

  const _ResponseCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(text),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied')),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
