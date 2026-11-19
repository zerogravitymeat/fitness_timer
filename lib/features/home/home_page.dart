import 'package:flutter/material.dart';

import '../../engine/routine_compiler.dart';
import '../../models/presets.dart';
import '../../models/routine.dart';
import '../../services/run/run_client.dart';
import '../../services/run/run_labels.dart';
import '../run/run_page.dart';

/// 기본 홈 (기능 확인용). 글래스 디자인은 개발 7단계에서 입힌다.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // 앱을 다시 열었는데 운동이 진행 중이면 진행 화면으로 (docs/03 5.5절)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await RunClient.instance.reattach() && mounted) {
        _openRun();
      }
    });
  }

  Future<void> _start(Routine r) async {
    final ok = await RunClient.instance.start(r);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('타이머를 시작하지 못했어요')));
      return;
    }
    _openRun();
  }

  void _openRun() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RunPage()));
  }

  String _summary(Routine r) {
    final total = RunLabels.duration(RoutineCompiler.estimatedTotalMs(r));
    if (r.isReps) {
      return '${r.targetReps}회 × ${r.rounds}세트 · ${r.tempo.label} · 약 $total';
    }
    final base =
        '${RunLabels.duration(r.workMs)} / ${RunLabels.duration(r.restMs)} × ${r.rounds}';
    return '${r.sets > 1 ? '$base × ${r.sets}세트' : base} · 약 $total';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('피트니스 타이머')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('프리셋', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final r in Presets.all)
            Card(
              child: ListTile(
                title: Text(r.name),
                subtitle: Text(_summary(r)),
                trailing: IconButton.filled(
                  tooltip: '${r.name} 시작',
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => _start(r),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
