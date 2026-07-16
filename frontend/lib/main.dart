import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/app/app.dart';
import 'package:tt_mail_assistant/core/di/di.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init(); // Initialize dependencies
  runApp(const TTMailApp());
}
