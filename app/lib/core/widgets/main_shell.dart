import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../features/community/community_theme.dart';
import '../../features/community/screens/community_screen.dart';
import '../../features/projects/screens/browse_projects_screen.dart';
import '../../features/social/data/social_messaging_service.dart';
import '../../features/social/screens/conversations_screen.dart';
import '../../features/social/screens/friends_screen.dart';
import '../../features/social/screens/notifications_screen.dart';
import '../../features/profile/screens/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const Color _accent = Color(0xFF22D3C5);
  static const Color _textColor = Color(0xFFF2FFFF);
  static const Color _surface = Color(0xFF163332);

  static const List<String> _labels = [
    'Projects',
    'Community',
    'Messages',
    'Alerts',
    'Profile',
  ];

  static const List<IconData> _icons = [
    Icons.folder_outlined,
    Icons.forum_outlined,
    Icons.chat_bubble_outline,
    Icons.notifications_none_rounded,
    Icons.person_outline_rounded,
  ];

  static const List<IconData> _selectedIcons = [
    Icons.folder_rounded,
    Icons.forum_rounded,
    Icons.chat_bubble_rounded,
    Icons.notifications_rounded,
    Icons.person_rounded,
  ];

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

  void _openAlerts() {
    setState(() {
      _index = 3;
    });
  }

  Widget _buildNavItem(int index) {
    final selected = _index == index;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: _labels[index],
        child: InkWell(
          onTap: () => setState(() => _index = index),
          borderRadius: BorderRadius.circular(26),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? _accent.withValues(alpha: 0.09)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? _selectedIcons[index] : _icons[index],
                  size: 29,
                  color: selected
                      ? _accent
                      : _textColor.withValues(alpha: 0.88),
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _labels[index],
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 13,
                      color: selected
                          ? _accent
                          : _textColor.withValues(alpha: 0.92),
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingNavigationBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(38),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                color: _surface.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(38),
                border: Border.all(
                  color: _accent.withValues(alpha: 0.28),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.06),
                    blurRadius: 18,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(_labels.length, _buildNavItem),
              ),
            ),
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
            ProfileScreen(onAlertsTap: _openAlerts),
          ],
        ),
        bottomNavigationBar: _buildFloatingNavigationBar(),
      ),
    );
  }
}
