import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/presentation/screens/home/home_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/profile/profile_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/prompt/prompt_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/review/review_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/today/today_activity_screen.dart';
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
      body: _screens[_selectedIndex],

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PromptScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,

        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },

        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),

          const BottomNavigationBarItem(
            icon: Icon(Icons.today),
            label: 'Today',
          ),

          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.mark_email_unread),
                if (reviewCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      child: Text(
                        reviewCount > 99 ? '99+' : '$reviewCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Review',
          ),

          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
