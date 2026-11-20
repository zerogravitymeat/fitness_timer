/// 구간 종류 (docs/02_기능_명세.md 1장)
enum SegmentType {
  prep,
  work,
  rest,
  setRest,

  /// 코스에서 루틴과 루틴 사이 휴식 (docs/02 8-1장)
  courseRest,
}

/// 타이머가 진행하는 가장 작은 단위. [RoutineCompiler]가 만든다.
class Segment {
  const Segment({
    required this.type,
    required this.durationMs,
    required this.round,
    required this.set,
    this.targetReps,
    this.part = 0,
  });

  final SegmentType type;

  /// 구간 길이. 횟수 모드 운동 구간은 `목표 횟수 × 1회 시간`.
  final int durationMs;

  /// 횟수 모드 운동 구간에서만 값이 있다.
  final int? targetReps;

  /// 1부터 시작. 준비 구간은 1.
  final int round;

  /// 1부터 시작. 준비 구간은 1.
  final int set;

  /// 코스 안에서 몇 번째 루틴의 구간인지 (0부터). 루틴 하나면 항상 0.
  /// 루틴 사이 휴식은 **다음** 루틴의 번호를 가진다.
  final int part;

  bool get isRepWork => type == SegmentType.work && targetReps != null;
  bool get isRest =>
      type == SegmentType.rest ||
      type == SegmentType.setRest ||
      type == SegmentType.courseRest;

  /// 루틴의 첫 운동 구간 (코스에서 루틴 이름을 알릴 때)
  bool get isFirstWork => type == SegmentType.work && round == 1 && set == 1;

  @override
  String toString() =>
      'Segment(${type.name} ${durationMs}ms p$part r$round s$set${targetReps != null ? ' ${targetReps}reps' : ''})';
}
