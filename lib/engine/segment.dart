/// 구간 종류 (docs/02_기능_명세.md 1장)
enum SegmentType { prep, work, rest, setRest }

/// 타이머가 진행하는 가장 작은 단위. [RoutineCompiler]가 만든다.
class Segment {
  const Segment({
    required this.type,
    required this.durationMs,
    required this.round,
    required this.set,
    this.targetReps,
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

  bool get isRepWork => type == SegmentType.work && targetReps != null;
  bool get isRest => type == SegmentType.rest || type == SegmentType.setRest;

  @override
  String toString() =>
      'Segment(${type.name} ${durationMs}ms r$round s$set${targetReps != null ? ' ${targetReps}reps' : ''})';
}
