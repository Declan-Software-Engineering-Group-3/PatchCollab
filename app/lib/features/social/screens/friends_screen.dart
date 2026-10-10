import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/friendship_model.dart';
import '../data/social_user_model.dart';
import '../providers/social_providers.dart';
import 'chat_screen.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider);
    final requests = ref.watch(incomingFriendRequestsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(friendsProvider);
        ref.invalidate(incomingFriendRequestsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // SIGN OUT BUTTON
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
            ),
          ),

          const SizedBox(height: 8),

          FilledButton.icon(
            onPressed: () => showSearch(
              context: context,
              delegate: FriendSearchDelegate(ref),
            ),
            icon: const Icon(Icons.person_add),
            label: const Text('Find people'),
          ),

          const SizedBox(height: 20),

          Text(
            'Friend requests',
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: 8),

          requests.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Could not load requests: $e'),
            data: (items) {
              if (items.isEmpty) {
                return const _EmptyCard(
                  message: 'No pending friend requests.',
                );
              }

              return Column(
                children: items.map((request) {
                  return _RequestTile(request: request);
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 24),

          Text(
            'Friends',
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: 8),

          friends.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => _EmptyCard(
              message: 'Could not load friends: $e',
            ),
            data: (items) {
              if (items.isEmpty) {
                return const _EmptyCard(
                  message:
                      'You have no friends yet. Find someone to connect with.',
                );
              }

              return Column(
                children: items.map((friendship) {
                  final uid = ref.read(currentSocialUserIdProvider)!;

                  return _FriendTile(
                    userId: friendship.otherUserId(uid),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  const _RequestTile({
    required this.request,
  });

  final Friendship request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(
      socialUserProvider(request.userId),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: user.when(
          loading: () => const ListTile(
            title: Text('Loading...'),
          ),
          error: (e, _) => ListTile(
            title: Text('Could not load user: $e'),
          ),
          data: (person) {
            if (person == null) {
              return const ListTile(
                title: Text('User not found'),
              );
            }

            return ListTile(
              leading: _Avatar(user: person),
              title: Text(person.displayName),
              subtitle: Text(person.email),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Accept',
                    onPressed: () async {
                      await ref
                          .read(socialActionProvider.notifier)
                          .acceptFriendRequest(
                            request.friendshipId,
                          );
                    },
                    icon: const Icon(Icons.check),
                  ),
                  IconButton(
                    tooltip: 'Reject',
                    onPressed: () async {
                      await ref
                          .read(socialActionProvider.notifier)
                          .rejectFriendRequest(
                            request.friendshipId,
                          );
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FriendTile extends ConsumerWidget {
  const _FriendTile({
    required this.userId,
  });

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(
      socialUserProvider(userId),
    );

    return Card(
      child: user.when(
        loading: () => const ListTile(
          title: Text('Loading...'),
        ),
        error: (e, _) => ListTile(
          title: Text('Could not load user: $e'),
        ),
        data: (person) {
          if (person == null) {
            return const ListTile(
              title: Text('User not found'),
            );
          }

          return ListTile(
            leading: _Avatar(user: person),
            title: Text(person.displayName),
            subtitle: Text(person.email),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    otherUserId: person.userId,
                    otherUserName: person.displayName,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class FriendSearchDelegate extends SearchDelegate<SocialUser?> {
  FriendSearchDelegate(this.ref);

  final WidgetRef ref;

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            onPressed: () => query = '',
            icon: const Icon(Icons.clear),
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        onPressed: () => close(context, null),
        icon: const Icon(Icons.arrow_back),
      );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(
        child: Text('Search by display name.'),
      );
    }

    final result = ref.watch(
      friendSearchProvider(query.trim()),
    );

    return result.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (e, _) => Center(
        child: Text('Search failed: $e'),
      ),
      data: (users) {
        if (users.isEmpty) {
          return const Center(
            child: Text('No users found.'),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (_, index) {
            final user = users[index];

            return ListTile(
              leading: _Avatar(user: user),
              title: Text(user.displayName),
              subtitle: Text(user.email),
              trailing: IconButton(
                tooltip: 'Send friend request',
                icon: const Icon(Icons.person_add),
                onPressed: () async {
                  await ref
                      .read(socialActionProvider.notifier)
                      .sendFriendRequest(
                        user.userId,
                      );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Friend request sent.',
                        ),
                      ),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.user,
  });

  final SocialUser user;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundImage: user.profileImageUrl == null
          ? null
          : NetworkImage(user.profileImageUrl!),
      child: user.profileImageUrl == null
          ? Text(
              user.displayName.isEmpty
                  ? '?'
                  : user.displayName[0].toUpperCase(),
            )
          : null,
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}