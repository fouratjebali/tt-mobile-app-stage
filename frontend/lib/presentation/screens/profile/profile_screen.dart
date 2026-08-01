import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/theme/theme_controller.dart';
import 'package:tt_mail_assistant/domain/repositories/auth_repository.dart';
import 'package:tt_mail_assistant/presentation/screens/auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool autoProcessing = true;
  bool notifications = true;
  bool darkMode = true;

  double confidenceThreshold = 80;

  @override
  void initState() {
    super.initState();
    darkMode = getIt<ThemeController>().isDark;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile & Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account section
          const Text(
            "Account",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: const Text("User"),
              subtitle: const Text("user@email.com"),
            ),
          ),

          const SizedBox(height: 25),

          // Preferences
          const Text(
            "Preferences",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          SwitchListTile(
            title: const Text("Auto-processing"),
            subtitle: const Text("Automatically process incoming emails"),
            value: autoProcessing,
            onChanged: (value) {
              setState(() {
                autoProcessing = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text("Notifications"),
            value: notifications,
            onChanged: (value) {
              setState(() {
                notifications = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text("Dark mode"),
            value: darkMode,
            onChanged: (value) async {
              setState(() {
                darkMode = value;
              });

              await getIt<ThemeController>().setDarkMode(value);
            },
          ),

          const SizedBox(height: 25),

          // Threshold
          const Text(
            "AI Threshold",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          Slider(
            value: confidenceThreshold,
            min: 0,
            max: 100,
            divisions: 10,
            label: "${confidenceThreshold.round()}%",
            onChanged: (value) {
              setState(() {
                confidenceThreshold = value;
              });
            },
          ),

          Text("Confidence threshold: ${confidenceThreshold.round()}%"),

          const SizedBox(height: 30),

          // Logout
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text("Logout"),
            onPressed: () async {
              await getIt<AuthRepository>().signOut();

              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
