import '../models/routine.dart';
import '../models/workout.dart';
import 'segment.dart';

/// 루틴을 실행 순서대로 펼친 구간 목록으로 바꾼다.
/// 구간 경계 규칙은 이곳에서만 처리한다 (docs/02_기능_명세.md 2.2절).
abstract final class RoutineCompiler {
  ///
  /// [part]는 코스 안의 루틴 번호, [withPrep]이 false면 준비 구간을 넣지 않는다.
  static List<Segment> compile(
    Routine routine, {
    int part = 0,
    bool withPrep = true,
  }) {
    final r = routine.normalized();
    final out = <Segment>[];
    if (withPrep && r.prepMs > 0) {
      out.add(
        Segment(
          type: SegmentType.prep,
          durationMs: r.prepMs,
          round: 1,
          set: 1,
          part: part,
        ),
      );
    }

    final sets = r.effectiveSets;
    for (var set = 1; set <= sets; set++) {
      for (var round = 1; round <= r.rounds; round++) {
        out.add(
          Segment(
            type: SegmentType.work,
            durationMs: r.workDurationMs,
            targetReps: r.isReps ? r.targetReps : null,
            round: round,
            set: set,
            part: part,
          ),
        );

        final isLastRound = round == r.rounds;
        final skipRest = r.restMs <= 0 || (isLastRound && r.skipLastRest);
        if (!skipRest) {
          out.add(
            Segment(
              type: SegmentType.rest,
              durationMs: r.restMs,
              round: round,
              set: set,
              part: part,
            ),
          );
        }
      }
      if (set < sets && r.setRestMs > 0) {
        out.add(
          Segment(
            type: SegmentType.setRest,
            durationMs: r.setRestMs,
            round: r.rounds,
            set: set,
            part: part,
          ),
        );
      }
    }

    // 루틴 맨 끝의 휴식은 의미가 없으므로 항상 뺀다 (뒤에 운동이 없음).
    while (out.isNotEmpty && out.last.isRest) {
      out.removeLast();
    }
    return out;
  }

  /// 예상 총 시간 (docs/02_기능_명세.md 2.4절)
  static int estimatedTotalMs(Routine r) =>
      compile(r).fold(0, (sum, s) => sum + s.durationMs);

  /// 코스(또는 루틴 하나)를 구간 목록으로 (docs/02 8-1장).
  ///
  /// - 준비 구간은 첫 루틴 것만 쓴다.
  /// - 각 루틴 끝의 휴식은 빠지고, 그 자리에 루틴 사이 휴식이 들어간다 (0이면 없음).
  static List<Segment> compileWorkout(Workout w) {
    final out = <Segment>[];
    for (var i = 0; i < w.routines.length; i++) {
      final segs = compile(w.routines[i], part: i, withPrep: i == 0);
      if (segs.isEmpty) continue;
      final rest = i > 0 ? w.restAfter(i - 1) : 0;
      if (out.isNotEmpty && rest > 0) {
        out.add(
          Segment(
            type: SegmentType.courseRest,
            durationMs: rest,
            round: 1,
            set: 1,
            part: i,
          ),
        );
      }
      out.addAll(segs);
    }
    return out;
  }

  static int estimatedWorkoutMs(Workout w) =>
      compileWorkout(w).fold(0, (sum, s) => sum + s.durationMs);
}
