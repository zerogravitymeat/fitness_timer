import '../../engine/segment.dart';
import 'run_view.dart';

/// 진행 화면과 알림 영역이 함께 쓰는 표시 문구 (docs/03_화면_설계.md 5장, docs/02 2.5절)
abstract final class RunLabels {
  static String segment(SegmentType? t, {required bool isReps}) => switch (t) {
    SegmentType.prep => '준비',
    SegmentType.work => '운동',
    SegmentType.rest => isReps ? '세트 간 휴식' : '휴식',
    SegmentType.setRest => '세트 간 휴식',
    null => '완료',
  };

  /// 시간 모드: "라운드 3/8 · 세트 1/2", 횟수 모드: "세트 2/3"
  static String progress(RunView v) {
    if (v.isReps) return '세트 ${v.round}/${v.rounds}';
    final round = '라운드 ${v.round}/${v.rounds}';
    return v.sets > 1 ? '$round · 세트 ${v.set}/${v.sets}' : round;
  }

  static String next(RunView v) {
    final t = v.nextType;
    if (t == null) return '다음: 완료';
    final name = segment(t, isReps: v.isReps);
    if (v.nextTargetReps != null) return '다음: $name ${v.nextTargetReps}회';
    return '다음: $name ${duration(v.nextDurationMs ?? 0)}';
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

  static String duration(int ms) {
    final s = ms ~/ 1000;
    if (s < 60) return '$s초';
    return s % 60 == 0 ? '${s ~/ 60}분' : '${s ~/ 60}분 ${s % 60}초';
  }
}
