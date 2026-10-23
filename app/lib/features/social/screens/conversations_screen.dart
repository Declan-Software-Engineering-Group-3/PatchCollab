import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../providers/social_providers.dart';
import 'chat_screen.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final uid = ref.watch(currentSocialUserIdProvider);

    if (uid == null) {
      return const Center(child: Text('Sign in to view messages.'));
    }

    return conversations.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load messages: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No conversations yet.\nOpen a friend or user profile to start messaging.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (_, index) {
            final conversation = items[index];
            final otherId = conversation.otherUserId(uid);
            return _ConversationTile(
              userId: otherId,
              lastMessage: conversation.lastMessage,
              lastMessageAt: conversation.lastMessageAt.toDate(),
              conversationId: conversation.conversationId,
            );
          },
        );
      },
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({
    required this.userId,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.conversationId,
  });

  final String userId;
  final String lastMessage;
  final DateTime lastMessageAt;
  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(socialUserProvider(userId));

    return user.when(
      loading: () => const ListTile(title: Text('Loading...')),
      error: (e, _) => ListTile(title: Text('Could not load user: $e')),
      data: (person) {
        if (person == null) return const ListTile(title: Text('User not found'));
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: person.profileImageUrl == null
                ? null
                : NetworkImage(person.profileImageUrl!),
            child: person.profileImageUrl == null
                ? Text(person.displayName.isEmpty ? '?' : person.displayName[0])
                : null,
          ),
          title: Text(person.displayName),
          subtitle: Text(
            lastMessage.isEmpty ? 'No messages yet' : lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            _timeLabel(lastMessageAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                otherUserId: person.userId,
                otherUserName: person.displayName,
              ),
            ),
          ),
        );
      },
    );
  }

  String _timeLabel(DateTime value) {
    final now = DateTime.now();
    if (now.difference(value).inDays == 0) {
      final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
      final minute = value.minute.toString().padLeft(2, '0');
      return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
    }
    return '${value.day}/${value.month}';
  }
}
