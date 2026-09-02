import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/localization/app_localizations.dart';
import 'package:tt_mail_assistant/presentation/screens/formations/formations_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/home/home_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/profile/profile_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/review/review_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/today/today_activity_screen.dart';
import 'package:tt_mail_assistant/presentation/viewmodels/home_view_model.dart';
import 'package:tt_mail_assistant/presentation/viewmodels/review_view_model.dart';
import 'package:tt_mail_assistant/presentation/widgets/app_bottom_navigation_bar.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _selectedIndex;
  late final ReviewViewModel _reviewViewModel;
  Timer? _reviewRefreshTimer;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 3).toInt();
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
    final l10n = context.l10n;
    final items = [
      AppNavigationItemData(
        label: l10n.t('nav.home'),
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      AppNavigationItemData(
        label: l10n.t('nav.today'),
        icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_today_rounded,
      ),
      AppNavigationItemData(
        label: l10n.t('nav.review'),
        icon: Icons.mark_email_unread_outlined,
        activeIcon: Icons.mark_email_unread_rounded,
      ),
      AppNavigationItemData(
        label: l10n.t('nav.profile'),
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
      ),
    ];
    final reviewCount = _reviewViewModel.pendingCount;
    final screens = [
      HomeScreen(onSelectTab: _selectTab),
      const TodayActivityScreen(),
      const ReviewScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      floatingActionButton: AppCenterActionFab(
        icon: Icons.school_rounded,
        heroTag: 'formationsFab',
        onPressed: _openFormations,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: _selectedIndex,
        reviewCount: reviewCount,
        items: items,
        onItemSelected: _selectTab,
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

  Future<void> _openFormations() async {
    final selectedTab = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (context) => const FormationsScreen()),
    );
    if (!mounted || selectedTab == null) return;
    _selectTab(selectedTab);
  }
}
