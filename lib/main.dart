import 'package:flutter/material.dart';

import 'app/app_services.dart';
import 'features/home/home_page.dart';
import 'services/run/run_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  RunClient.instance.init();
  await AppServices.init();
  runApp(const FitnessTimerApp());
}

class FitnessTimerApp extends StatelessWidget {
  const FitnessTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '피트니스 타이머',
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
