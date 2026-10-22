import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../community/community_theme.dart';
import '../data/project_options.dart';
import '../providers/projects_provider.dart';

class CreateProjectScreen extends ConsumerStatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  ConsumerState<CreateProjectScreen> createState() =>
      _CreateProjectScreenState();
}

class _CreateProjectScreenState extends ConsumerState<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _githubController = TextEditingController();

  String? _technology;
  String? _difficulty;
  String? _category;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _githubController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_technology == null || _difficulty == null || _category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick a technology, difficulty and category.'),
        ),
      );
      return;
    }

    await ref
        .read(projectCreationProvider.notifier)
        .createProject(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          technology: _technology!,
          difficulty: _difficulty!,
          category: _category!,
          githubUrl: _githubController.text.trim().isEmpty
              ? null
              : _githubController.text.trim(),
        );

    final state = ref.read(projectCreationProvider);
    if (!mounted) return;

    state.when(
      data: (_) => Navigator.of(context).pop(),
      error: (err, stack) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not create project: $err'))),
      loading: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final creationState = ref.watch(projectCreationProvider);
    final isSubmitting = creationState.isLoading;

    return Theme(
      data: communityTheme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Create a Project')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Project Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              Text('Technology', style: communityTheme.textTheme.labelMedium),
              const SizedBox(height: 8),
              _OptionChips(
                options: projectTechnologies,
                selected: _technology,
                onSelected: (v) => setState(() => _technology = v),
              ),
              const SizedBox(height: 16),

              Text('Difficulty', style: communityTheme.textTheme.labelMedium),
              const SizedBox(height: 8),
              _OptionChips(
                options: projectDifficulties,
                selected: _difficulty,
                onSelected: (v) => setState(() => _difficulty = v),
              ),
              const SizedBox(height: 16),

              Text('Category', style: communityTheme.textTheme.labelMedium),
              const SizedBox(height: 8),
              _OptionChips(
                options: projectCategories,
                selected: _category,
                onSelected: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _githubController,
                decoration: const InputDecoration(
                  labelText: 'GitHub Repository (optional)',
                  hintText: 'github.com/owner/repository',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: isSubmitting ? null : _submit,
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Project'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// single-select chip row used for technology/difficulty/category. no "all"
/// option here, unlike the browse filters, since a project needs exactly one
/// value for each field.
class _OptionChips extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _OptionChips({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (option) => ChoiceChip(
              label: Text(option),
              selected: selected == option,
              onSelected: (_) => onSelected(option),
            ),
          )
          .toList(),
    );
  }
}
