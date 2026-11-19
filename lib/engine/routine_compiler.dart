import '../models/routine.dart';
import 'segment.dart';

/// 루틴을 실행 순서대로 펼친 구간 목록으로 바꾼다.
/// 구간 경계 규칙은 이곳에서만 처리한다 (docs/02_기능_명세.md 2.2절).
abstract final class RoutineCompiler {
  static List<Segment> compile(Routine routine) {
    final r = routine.normalized();
    final out = <Segment>[];
    if (r.prepMs > 0) {
      out.add(
        Segment(type: SegmentType.prep, durationMs: r.prepMs, round: 1, set: 1),
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
}
