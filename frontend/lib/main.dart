import 'package:flutter/material.dart';
import 'package:frontend/app/app.dart';
import 'package:frontend/core/di/di.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init(); // Initialize dependencies
  runApp(const TTMailApp());
}