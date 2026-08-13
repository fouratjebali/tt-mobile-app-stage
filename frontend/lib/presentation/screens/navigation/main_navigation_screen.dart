import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/presentation/screens/home/home_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/profile/profile_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/prompt/prompt_screen.dart';
import 'package:tt_mail_assistant/presentation/screens/today/today_activity_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  final List<Widget> _screens = const [
    HomeScreen(),
    TodayActivityScreen(),
    Center(child: Text('Review')),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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

                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
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

































































































