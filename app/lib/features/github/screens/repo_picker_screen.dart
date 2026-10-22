import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../community/community_theme.dart';
import '../data/github_repo_model.dart';
import '../data/github_repository.dart';
import '../providers/github_providers.dart';

/// Connect GitHub, choose a repository or unlink the current one.
/// Pops with a [RepoPickerResult]; a null repo means unlink.
class RepoPickerScreen extends ConsumerStatefulWidget {
  final GithubRepo? current;

  const RepoPickerScreen({super.key, this.current});

  @override
  ConsumerState<RepoPickerScreen> createState() => _RepoPickerScreenState();
}

class _RepoPickerScreenState extends ConsumerState<RepoPickerScreen> {
  bool _busy = false;

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    try {
      await ref.read(githubRepositoryProvider).connect();
      ref.invalidate(githubReposProvider);
    } catch (e) {
      if (mounted) _message(e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect GitHub?'),
        content: const Text(
          'This revokes PatchCollab\'s access and unlinks the repositories '
          'on your projects and review requests.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(githubRepositoryProvider).disconnect();
      ref.invalidate(githubReposProvider);
      // anything linked to this picker is gone now
      if (mounted && widget.current != null) {
        Navigator.of(context).pop(const RepoPickerResult(null));
        return;
      }
    } catch (e) {
      if (mounted) _message(e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final reposAsync = ref.watch(githubReposProvider);

    return Theme(
      data: communityTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Choose a repository'),
          actions: [
            if (reposAsync.hasValue)
              PopupMenuButton<String>(
                onSelected: (_) => _disconnect(),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'disconnect',
                    child: Text('Disconnect GitHub'),
                  ),
                ],
              ),
          ],
        ),
        body: Stack(
          children: [
            reposAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => err is GithubNotConnectedException
                  ? _ConnectPrompt(onConnect: _busy ? null : _connect)
                  : _ErrorView(
                      message: err.toString().replaceFirst('Exception: ', ''),
                      onRetry: () => ref.invalidate(githubReposProvider),
                    ),
              data: (repos) => _RepoList(
                repos: repos,
                current: widget.current,
                onPick: (repo) =>
                    Navigator.of(context).pop(RepoPickerResult(repo)),
                onUnlink: () =>
                    Navigator.of(context).pop(const RepoPickerResult(null)),
              ),
            ),
            if (_busy)
              const ColoredBox(
                color: Colors.black38,
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConnectPrompt extends StatelessWidget {
  final VoidCallback? onConnect;

  const _ConnectPrompt({required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Connect GitHub to attach a repository. PatchCollab can only '
              'read your public repositories.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onConnect,
              child: const Text('Connect GitHub'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _RepoList extends StatelessWidget {
  final List<GithubRepo> repos;
  final GithubRepo? current;
  final ValueChanged<GithubRepo> onPick;
  final VoidCallback onUnlink;

  const _RepoList({
    required this.repos,
    required this.current,
    required this.onPick,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (current != null)
          ListTile(
            leading: const Icon(Icons.link_off),
            title: Text('Unlink ${current!.fullName}'),
            onTap: onUnlink,
          ),
        if (repos.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No repositories found.')),
          ),
        for (final repo in repos)
          ListTile(
            leading: Icon(
              repo.isPrivate ? Icons.lock_outline : Icons.book_outlined,
            ),
            title: Text(repo.fullName),
            subtitle: Text('Default branch: ${repo.defaultBranch}'),
            trailing: repo.fullName == current?.fullName
                ? const Icon(Icons.check)
                : null,
            onTap: () => onPick(repo),
          ),
      ],
    );
  }
}
