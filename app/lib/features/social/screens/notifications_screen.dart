import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_model.dart';
import '../providers/social_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return notifications.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load notifications: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('You have no notifications.'));
        }

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, index) => const Divider(height: 1),
          itemBuilder: (_, index) {
            return _NotificationTile(notification: items[index]);
          },
        );
      },
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});
  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(notification.notificationId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => ref
          .read(socialActionProvider.notifier)
          .deleteNotification(notification.notificationId),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(_iconFor(notification.type)),
        ),
        title: Text(
          notification.message,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Text(_timeLabel(notification.createdAt.toDate())),
        tileColor: notification.isRead
            ? null
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        onTap: notification.isRead
            ? null
            : () => ref
                .read(socialActionProvider.notifier)
                .markNotificationRead(notification.notificationId),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'friendRequest':
        return Icons.person_add;
      case 'newMessage':
        return Icons.chat;
      case 'newAnswer':
        return Icons.question_answer;
      case 'newReviewRequest':
        return Icons.rate_review;
      default:
        return Icons.notifications;
    }
  }

  String _timeLabel(DateTime value) {
    final now = DateTime.now();
    if (now.difference(value).inDays == 0) {
      return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    }
    return '${value.day}/${value.month}/${value.year}';
  }
}
