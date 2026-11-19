import '../../engine/routine_compiler.dart';
import '../../models/routine.dart';
import '../../services/run/run_labels.dart';

/// 루틴 요약 표기 (docs/03_화면_설계.md 3장 "루틴 항목")
abstract final class RoutineSummary {
  /// 시간 모드: `20초/10초 × 8` (+ `× 2세트`), 횟수 모드: `12회 × 3세트 · 2-0-1`
  static String of(Routine r) {
    if (r.isReps) return '${r.targetReps}회 × ${r.rounds}세트 · ${r.tempo.label}';
    final base =
        '${RunLabels.duration(r.workMs)}/${RunLabels.duration(r.restMs)} × ${r.rounds}';
    return r.sets > 1 ? '$base × ${r.sets}세트' : base;
  }

  /// 1분 이상이면 "약 N분", 1분 미만이면 "N초"
  static String estimate(Routine r) {
    final ms = RoutineCompiler.estimatedTotalMs(r);
    if (ms < 60000) return '${ms ~/ 1000}초';
    return '약 ${(ms / 60000).round()}분';
  }
}
