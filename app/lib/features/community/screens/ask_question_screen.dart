import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../github/data/diff_source.dart';
import '../../github/data/github_repo_model.dart';
import '../../github/screens/repo_picker_screen.dart';
import '../data/community_options.dart';
import '../providers/community_providers.dart';
import '../community_theme.dart';

class AskQuestionScreen extends ConsumerStatefulWidget {
  const AskQuestionScreen({super.key});

  @override
  ConsumerState<AskQuestionScreen> createState() => _AskQuestionScreenState();
}

class _AskQuestionScreenState extends ConsumerState<AskQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _codeController = TextEditingController();
  final _diffValueController = TextEditingController();

  String? _language;
  String _category = questionCategories.first;
  String _type = typeQuestion;
  bool _saving = false;
  GithubRepo? _repo;
  DiffKind _diffKind = DiffKind.commit;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _codeController.dispose();
    _diffValueController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final code = _codeController.text.trim();
    final diffValue = _diffValueController.text.trim();

    try {
      await ref
          .read(communityRepositoryProvider)
          .createQuestion(
            userId: ref.read(currentUserIdProvider),
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
            category: _category,
            type: _type,
            language: _language,
            codeSnippet: code.isEmpty ? null : code,
            repo: _type == typeReviewRequest ? _repo : null,
            diff:
                _type == typeReviewRequest &&
                    _repo != null &&
                    diffValue.isNotEmpty
                ? DiffSource(_diffKind, diffValue)
                : null,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not post question: $e')));
    }
  }

  Future<void> _pickRepo() async {
    final result = await Navigator.of(context).push<RepoPickerResult>(
      MaterialPageRoute(builder: (_) => RepoPickerScreen(current: _repo)),
    );
    if (result == null || !mounted) return;
    setState(() => _repo = result.repo);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: communityTheme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Ask a Question')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: typeQuestion, label: Text('Question')),
                  ButtonSegment(
                    value: typeReviewRequest,
                    label: Text('Review request'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Give your question a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Explain what you need help with';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: questionCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) => setState(() => _category = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _language,
                decoration: const InputDecoration(
                  labelText: 'Language (optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None'),
                  ),
                  ...questionLanguages.map(
                    (l) => DropdownMenuItem<String?>(value: l, child: Text(l)),
                  ),
                ],
                onChanged: (value) => setState(() => _language = value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                minLines: 4,
                maxLines: 12,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  labelText: 'Code snippet (optional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_type == typeReviewRequest) ...[
                const SizedBox(height: 16),
                _RepoSection(
                  repo: _repo,
                  onPick: _pickRepo,
                  diffKind: _diffKind,
                  onKindChanged: (k) => setState(() => _diffKind = k),
                  valueController: _diffValueController,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Posting...' : 'Post'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RepoSection extends StatelessWidget {
  final GithubRepo? repo;
  final VoidCallback onPick;
  final DiffKind diffKind;
  final ValueChanged<DiffKind> onKindChanged;
  final TextEditingController valueController;

  const _RepoSection({
    required this.repo,
    required this.onPick,
    required this.diffKind,
    required this.onKindChanged,
    required this.valueController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.link),
          label: Text(
            repo == null ? 'Attach a GitHub repository' : repo!.fullName,
          ),
        ),
        if (repo != null) ...[
          const SizedBox(height: 16),
          SegmentedButton<DiffKind>(
            segments: const [
              ButtonSegment(value: DiffKind.commit, label: Text('Commit')),
              ButtonSegment(value: DiffKind.compare, label: Text('Compare')),
              ButtonSegment(value: DiffKind.pull, label: Text('Pull request')),
            ],
            selected: {diffKind},
            onSelectionChanged: (s) => onKindChanged(s.first),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: valueController,
            decoration: InputDecoration(
              labelText: switch (diffKind) {
                DiffKind.commit => 'Commit sha (optional)',
                DiffKind.compare => 'base...head (optional)',
                DiffKind.pull => 'Pull request number (optional)',
              },
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return null;
              return DiffSource.validate(diffKind, text);
            },
          ),
        ],
      ],
    );
  }
}
