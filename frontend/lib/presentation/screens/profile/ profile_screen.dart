import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile & Settings"),
        centerTitle: false,
      ),
      body: const Center(
        child: Text(
          "Profile Screen",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}