import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_services.dart';
import 'design/app_theme.dart';
import 'design/glass.dart';
import 'features/home/home_page.dart';
import 'l10n/l10n.dart';
import 'services/run/run_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  RunClient.instance.init();
  // 앱에 포함한 Pretendard 글꼴의 라이선스를 "오픈소스 라이선스" 화면에 표시 (OFL 1.1)
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Pretendard',
    ], await rootBundle.loadString('assets/fonts/Pretendard-LICENSE.txt'));
  });
  // 저장된 루틴·설정 읽기. 그동안은 시스템 시작 화면(어두운 단색)이 떠 있다.
  await AppServices.init();
  runApp(const FitnessTimerApp());
}

class FitnessTimerApp extends StatelessWidget {
  const FitnessTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness Timer',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // 글래스모피즘, 다크 테마만 (docs/04)
      theme: AppTheme.dark(),
      // 모든 화면 뒤에 공통 배경. 진행 화면은 자기 배경(구간 색)으로 덮는다.
      builder: (context, child) => AppBackground(child: child!),
      home: const HomePage(),
    );
  }
}
