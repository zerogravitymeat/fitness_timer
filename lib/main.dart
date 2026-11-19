import 'package:flutter/material.dart';

import 'features/home/home_page.dart';
import 'services/run/run_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  RunClient.instance.init();
  runApp(const HealthTimerApp());
}

class HealthTimerApp extends StatelessWidget {
  const HealthTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Timer',
      debugShowCheckedModeBanner: false,
      // MVP는 다크 테마만 (docs/04 2.4절). 글래스 디자인은 개발 7단계에서.
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF6C7CFF),
        scaffoldBackgroundColor: const Color(0xFF0B0F1A),
      ),
      home: const HomePage(),
    );
  }
}
