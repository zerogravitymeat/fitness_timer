import '../../engine/routine_compiler.dart';
import '../../l10n/app_localizations.dart';
import '../../models/routine.dart';
import '../../models/workout.dart';
import '../../services/run/run_labels.dart';

/// 루틴 요약 표기 (docs/03_화면_설계.md 3장 "루틴 항목")
abstract final class RoutineSummary {
  /// 시간 모드: `20초/10초 × 8` (+ `× 2세트`), 횟수 모드: `12회 × 3세트 · 1회 3초`
  static String of(AppLocalizations l, Routine r) {
    if (r.isReps) {
      return l.summaryReps(
        r.targetReps,
        r.rounds,
        l.tempoPerRep(r.tempo.seconds),
      );
    }
    final base =
        '${RunLabels.duration(l, r.workMs)}/${RunLabels.duration(l, r.restMs)} × ${r.rounds}';
    return r.sets > 1 ? l.summaryWithSets(base, r.sets) : base;
  }

  /// 1분 이상이면 "약 N분", 1분 미만이면 "N초"
  static String estimate(AppLocalizations l, Routine r) =>
      estimateMs(l, RoutineCompiler.estimatedTotalMs(r));

  static String estimateMs(AppLocalizations l, int ms) {
    if (ms < 60000) return l.durationSeconds(ms ~/ 1000);
    return l.estimateAbout((ms / 60000).round());
  }

  /// 코스: `루틴 3개 · 약 18분` (docs/03 3장 "코스 항목")
  static String course(AppLocalizations l, Workout w) => w.routines.isEmpty
      ? l.courseNoRoutines
      : l.courseSummary(
          w.routines.length,
          estimateMs(l, RoutineCompiler.estimatedWorkoutMs(w)),
        );

  /// 코스 안의 루틴 이름 나열: `타바타 → 플랭크 → 근력 세트`
  static String courseNames(Workout w) =>
      w.routines.map((r) => r.name).join(' → ');
}
