import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/presentation/screens/home/home_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/profile/profile_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/prompt/prompt_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/review/review_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/today/today_activity_screen.dart';
import 'package:tt_mail_assistant/presentation/viewmodels/home_view_model.dart';
import 'package:tt_mail_assistant/presentation/viewmodels/review_view_model.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  late final ReviewViewModel _reviewViewModel;
  Timer? _reviewRefreshTimer;

  static const List<Widget> _screens = [
    HomeScreen(),
    TodayActivityScreen(),
    ReviewScreen(),
    ProfileScreen(),
  ];

  static const List<_NavItemData> _items = [
    _NavItemData(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _NavItemData(
      label: 'Today',
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today_rounded,
    ),
    _NavItemData(
      label: 'Review',
      icon: Icons.mark_email_unread_outlined,
      activeIcon: Icons.mark_email_unread_rounded,
    ),
    _NavItemData(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _reviewViewModel = getIt<ReviewViewModel>();
    _reviewViewModel.addListener(_onReviewChanged);
    _reviewViewModel.loadReviewEmails();
    _reviewRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _reviewViewModel.refreshSilently();
    });
  }

  @override
  void dispose() {
    _reviewRefreshTimer?.cancel();
    _reviewViewModel.removeListener(_onReviewChanged);
    super.dispose();
  }

  void _onReviewChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final reviewCount = _reviewViewModel.pendingCount;

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: _FloatingNavigationBar(
        selectedIndex: _selectedIndex,
        reviewCount: reviewCount,
        items: _items,
        onItemSelected: _selectTab,
        onAssistantPressed: _openPrompt,
      ),
    );
  }

  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
    if (index == 2) {
      _reviewViewModel.refreshSilently();
    } else if (index == 0) {
      getIt<HomeViewModel>().refresh();
    }
  }

  void _openPrompt() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PromptScreen()),
    );
  }
}

class _FloatingNavigationBar extends StatelessWidget {
  const _FloatingNavigationBar({
    required this.selectedIndex,
    required this.reviewCount,
    required this.items,
    required this.onItemSelected,
    required this.onAssistantPressed,
  });

  final int selectedIndex;
  final int reviewCount;
  final List<_NavItemData> items;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onAssistantPressed;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      minimum: EdgeInsets.fromLTRB(14, 0, 14, 12 + bottomPadding * 0.2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _NavSurface(
              child: Row(
                children: [
                  for (var index = 0; index < items.length; index++)
                    Expanded(
                      child: _NavItem(
                        data: items[index],
                        selected: selectedIndex == index,
                        badgeCount: index == 2 ? reviewCount : 0,
                        onTap: () => onItemSelected(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _AssistantButton(onPressed: onAssistantPressed),
        ],
      ),
    );
  }
}

class _NavSurface extends StatelessWidget {
  const _NavSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C1A) : AppPalette.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppPalette.line.withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final _NavItemData data;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppPalette.lavender : AppPalette.deepTeal;
    final inactiveColor =
        isDark
            ? Colors.white.withValues(alpha: 0.58)
            : AppPalette.pine.withValues(alpha: 0.58);

    return Semantics(
      button: true,
      selected: selected,
      label: data.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color:
                  selected
                      ? activeColor.withValues(alpha: isDark ? 0.18 : 0.12)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      selected ? data.activeIcon : data.icon,
                      size: 22,
                      color: selected ? activeColor : inactiveColor,
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -8,
                        top: -7,
                        child: _NavBadge(count: badgeCount),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    color: selected ? activeColor : inactiveColor,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    height: 1,
                  ),
                  child: Text(
                    data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantButton extends StatelessWidget {
  const _AssistantButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: AppPalette.deepTeal,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppPalette.deepTeal.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: AppPalette.white,
            size: 27,
          ),
        ),
      ),
    );
  }
}

class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: AppPalette.clay,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppPalette.paper, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: AppPalette.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
