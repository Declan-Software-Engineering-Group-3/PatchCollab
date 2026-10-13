import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/community/community_theme.dart';
import '../../features/community/screens/community_screen.dart';
import '../../features/projects/screens/browse_projects_screen.dart';
import '../../features/social/data/social_messaging_service.dart';
import '../../features/social/screens/conversations_screen.dart';
import '../../features/social/screens/friends_screen.dart';
import '../../features/social/screens/notifications_screen.dart';

// bottom nav for the whole app. projects and community bring their own
// app bars, messages and alerts are plain bodies so they get one here.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    unawaited(SocialMessagingService().initialize());
  }

  void _openFriends() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Theme(
          data: communityTheme,
          child: Scaffold(
            appBar: AppBar(title: const Text('Friends')),
            body: const FriendsScreen(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: communityTheme,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            const BrowseProjectsScreen(),
            const CommunityScreen(),
            Scaffold(
              appBar: AppBar(
                title: const Text('Messages'),
                actions: [
                  IconButton(
                    tooltip: 'Friends',
                    icon: const Icon(Icons.people_outline),
                    onPressed: _openFriends,
                  ),
                ],
              ),
              body: const ConversationsScreen(),
            ),
            Scaffold(
              appBar: AppBar(title: const Text('Alerts')),
              body: const NotificationsScreen(),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: 'Projects',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum),
              label: 'Community',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Messages',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_none),
              selectedIcon: Icon(Icons.notifications),
              label: 'Alerts',
            ),
          ],
        ),
      ),
    );
  }
}
