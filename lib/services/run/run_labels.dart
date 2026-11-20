import '../../engine/segment.dart';
import '../../l10n/app_localizations.dart';
import 'run_view.dart';

/// 진행 화면과 알림 영역이 함께 쓰는 표시 문구 (docs/03_화면_설계.md 5장, docs/02 2.5절)
/// 알림은 서비스 isolate에서 만들므로 BuildContext 대신 [AppLocalizations]를 받는다.
abstract final class RunLabels {
  static String segment(
    AppLocalizations l,
    SegmentType? t, {
    required bool isReps,
  }) => switch (t) {
    SegmentType.prep => l.segmentPrep,
    SegmentType.work => l.segmentWork,
    SegmentType.rest => isReps ? l.segmentSetRest : l.segmentRest,
    SegmentType.setRest => l.segmentSetRest,
    SegmentType.courseRest => l.segmentRest,
    null => l.done,
  };

  /// 시간 모드: "라운드 3/8 · 세트 1/2", 횟수 모드: "세트 2/3"
  static String progress(AppLocalizations l, RunView v) {
    // 코스의 루틴 사이 휴식: 지금까지 마친 루틴 수
    if (v.segmentType == SegmentType.courseRest) {
      return l.progressCourseRest(v.partIndex, v.partCount);
    }
    if (v.isReps) return l.progressSet(v.round, v.rounds);
    final round = l.progressRound(v.round, v.rounds);
    return v.sets > 1 ? l.progressRoundAndSet(round, v.set, v.sets) : round;
  }

  /// 코스: "2/4 스쿼트"
  static String coursePosition(RunView v) =>
      '${v.partIndex + 1}/${v.partCount} ${v.routineName}';

  static String next(AppLocalizations l, RunView v) {
    final t = v.nextType;
    if (t == null) return l.nextDone;
    // 코스에서 다음 루틴으로 넘어갈 때는 루틴 이름
    if (v.nextRoutineName != null) return l.nextItem(v.nextRoutineName!);
    final name = segment(l, t, isReps: v.isReps);
    if (v.nextTargetReps != null) {
      return l.nextItem('$name ${l.repsCount(v.nextTargetReps!)}');
    }
    return l.nextItem('$name ${duration(l, v.nextDurationMs ?? 0)}');
  }

  /// 남은 시간 표시. 16.2초 남았으면 0:17 (올림) → 0이 되는 순간 구간이 바뀐다.
  static String clock(int remainingMs) {
    final s = (remainingMs + 999) ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  /// 경과 시간 표시 (내림)
  static String elapsed(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  static String duration(AppLocalizations l, int ms) {
    final s = ms ~/ 1000;
    if (s < 60) return l.durationSeconds(s);
    return s % 60 == 0
        ? l.durationMinutes(s ~/ 60)
        : l.durationMinutesSeconds(s ~/ 60, s % 60);
  }
}
