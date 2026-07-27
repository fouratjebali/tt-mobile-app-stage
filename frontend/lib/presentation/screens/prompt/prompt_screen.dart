import 'package:flutter/material.dart';

class PromptScreen extends StatelessWidget {
  const PromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prompt'),
      ),
      body: const Center(
        child: Text(
          'Prompt Screen',
          style: TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}