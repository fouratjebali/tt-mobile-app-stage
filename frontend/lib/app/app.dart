import 'package:flutter/material.dart';
import 'package:frontend/presentation/screens/inbox/inbox_screen.dart';
class TTMailApp extends StatelessWidget {
  const TTMailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TT Mail Assistant',
      theme: ThemeData.dark(useMaterial3: true),
      home: const InboxScreen(),
    );
  }
}