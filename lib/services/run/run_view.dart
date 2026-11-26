import '../../engine/segment.dart';
import '../../engine/tempo_clock.dart';
import '../../engine/timer_core.dart';
import '../../models/routine.dart';

/// 서비스 → 화면으로 보내는 진행 상태 (docs/05_기술_설계.md 2.1절).
/// isolate 사이에서 주고받기 위해 Map으로 바꿀 수 있어야 한다.
class RunView {
  const RunView({
    required this.status,
    required this.routineName,
    this.workoutName = '',
    this.isCourse = false,
    this.partIndex = 0,
    this.partCount = 1,
    this.nextRoutineName,
    required this.isReps,
    required this.rounds,
    required this.sets,
    required this.segmentIndex,
    required this.segmentCount,
    required this.segmentType,
    required this.round,
    required this.set,
    required this.segmentElapsedMs,
    required this.segmentDurationMs,
    required this.totalActiveMs,
    required this.remainingTotalMs,
    this.nextType,
    this.nextDurationMs,
    this.nextTargetReps,
    this.targetReps,
    this.completedReps,
    this.repElapsedMs,
    this.repMs,
  });

  final RunStatus status;

  /// 지금 진행 중인 루틴 이름 (코스의 루틴 사이 휴식에서는 다음 루틴)
  final String routineName;

  /// 코스 이름. 루틴 하나면 루틴 이름과 같다.
  final String workoutName;
  final bool isCourse;

  /// 코스 안에서 몇 번째 루틴인지 (0부터)
  final int partIndex;
  final int partCount;

  /// 다음 구간이 다른 루틴의 첫 운동이면 그 루틴 이름 (코스)
  final String? nextRoutineName;
  final bool isReps;
  final int rounds;
  final int sets;
  final int segmentIndex;
  final int segmentCount;
  final SegmentType? segmentType;
  final int round;
  final int set;
  final int segmentElapsedMs;
  final int segmentDurationMs;
  final int totalActiveMs;
  final int remainingTotalMs;

  final SegmentType? nextType;
  final int? nextDurationMs;
  final int? nextTargetReps;

  // 횟수 모드 운동 구간에서만
  final int? targetReps;
  final int? completedReps;
  final int? repElapsedMs;

  /// 1회 시간
  final int? repMs;

  bool get isRepWork => targetReps != null;
  int get segmentRemainingMs =>
      (segmentDurationMs - segmentElapsedMs).clamp(0, segmentDurationMs);

  factory RunView.from(TimerCore core) {
    final s = core.snapshot();
    final seg = s.segment;
    final w = core.workout;
    // 끝났으면 마지막 루틴 기준
    final part = seg?.part ?? (w.routines.length - 1).clamp(0, 1 << 20);
    final r = w.routines.isEmpty ? null : w.routines[part];
    final nextIdx = s.segmentIndex + 1;
    final next = seg != null && nextIdx < core.segments.length
        ? core.segments[nextIdx]
        : null;
    final tp = s.tempo;
    return RunView(
      status: s.status,
      routineName: r?.name ?? w.name,
      workoutName: w.name,
      isCourse: w.isCourse,
      partIndex: part,
      partCount: w.isCourse ? w.routines.length : 1,
      nextRoutineName: w.isCourse && next != null && next.isFirstWork
          ? w.routines[next.part].name
          : null,
      isReps: r?.isReps ?? false,
      rounds: r?.rounds ?? 1,
      sets: r?.effectiveSets ?? 1,
      segmentIndex: s.segmentIndex,
      segmentCount: s.segmentCount,
      segmentType: seg?.type,
      round: seg?.round ?? r?.rounds ?? 1,
      set: seg?.set ?? r?.effectiveSets ?? 1,
      segmentElapsedMs: s.segmentElapsedMs,
      segmentDurationMs: s.segmentDurationMs,
      totalActiveMs: s.totalActiveMs,
      remainingTotalMs: s.remainingTotalMs,
      nextType: next?.type,
      nextDurationMs: next?.durationMs,
      nextTargetReps: next?.targetReps,
      targetReps: seg?.targetReps,
      completedReps: tp?.completedReps,
      repElapsedMs: tp?.repElapsedMs,
      repMs: seg?.isRepWork == true ? r?.tempo.repMs : null,
    );
  }

  Map<String, Object?> toMap() => {
    'status': status.name,
    'routineName': routineName,
    'workoutName': workoutName,
    'isCourse': isCourse,
    'partIndex': partIndex,
    'partCount': partCount,
    'nextRoutineName': nextRoutineName,
    'isReps': isReps,
    'rounds': rounds,
    'sets': sets,
    'segmentIndex': segmentIndex,
    'segmentCount': segmentCount,
    'segmentType': segmentType?.name,
    'round': round,
    'set': set,
    'segmentElapsedMs': segmentElapsedMs,
    'segmentDurationMs': segmentDurationMs,
    'totalActiveMs': totalActiveMs,
    'remainingTotalMs': remainingTotalMs,
    'nextType': nextType?.name,
    'nextDurationMs': nextDurationMs,
    'nextTargetReps': nextTargetReps,
    'targetReps': targetReps,
    'completedReps': completedReps,
    'repElapsedMs': repElapsedMs,
    'repMs': repMs,
  };

  factory RunView.fromMap(Map<Object?, Object?> m) {
    T? byName<T extends Enum>(List<T> values, Object? v) =>
        values.where((e) => e.name == v).firstOrNull;
    int i(String k) => (m[k] as num?)?.toInt() ?? 0;
    int? oi(String k) => (m[k] as num?)?.toInt();
    return RunView(
      status: byName(RunStatus.values, m['status']) ?? RunStatus.idle,
      routineName: m['routineName'] as String? ?? '',
      workoutName: m['workoutName'] as String? ?? '',
      isCourse: m['isCourse'] as bool? ?? false,
      partIndex: i('partIndex'),
      partCount: oi('partCount') ?? 1,
      nextRoutineName: m['nextRoutineName'] as String?,
      isReps: m['isReps'] as bool? ?? false,
      rounds: i('rounds'),
      sets: i('sets'),
      segmentIndex: i('segmentIndex'),
      segmentCount: i('segmentCount'),
      segmentType: byName(SegmentType.values, m['segmentType']),
      round: i('round'),
      set: i('set'),
      segmentElapsedMs: i('segmentElapsedMs'),
      segmentDurationMs: i('segmentDurationMs'),
      totalActiveMs: i('totalActiveMs'),
      remainingTotalMs: i('remainingTotalMs'),
      nextType: byName(SegmentType.values, m['nextType']),
      nextDurationMs: oi('nextDurationMs'),
      nextTargetReps: oi('nextTargetReps'),
      targetReps: oi('targetReps'),
      completedReps: oi('completedReps'),
      repElapsedMs: oi('repElapsedMs'),
      repMs: oi('repMs'),
    );
  }

  /// 화면 쪽에서 [elapsedSinceMs]만큼 시간이 흐른 것으로 보간한 값.
  /// 서비스가 1초에 몇 번만 보내도 화면은 매 프레임 부드럽게 그린다.
  RunView advancedBy(int elapsedSinceMs) {
    if (status != RunStatus.running || elapsedSinceMs <= 0) return this;
    final e = (segmentElapsedMs + elapsedSinceMs).clamp(0, segmentDurationMs);
    final d = e - segmentElapsedMs;
    int? completed = completedReps;
    int? repElapsed = repElapsedMs;
    if (isRepWork && repMs != null) {
      final pos = TempoClock.at(Tempo(repMs!), targetReps!, e);
      completed = pos.completedReps;
      repElapsed = pos.repElapsedMs;
    }
    return RunView(
      status: status,
      routineName: routineName,
      workoutName: workoutName,
      isCourse: isCourse,
      partIndex: partIndex,
      partCount: partCount,
      nextRoutineName: nextRoutineName,
      isReps: isReps,
      rounds: rounds,
      sets: sets,
      segmentIndex: segmentIndex,
      segmentCount: segmentCount,
      segmentType: segmentType,
      round: round,
      set: set,
      segmentElapsedMs: e,
      segmentDurationMs: segmentDurationMs,
      totalActiveMs: totalActiveMs + d,
      remainingTotalMs: (remainingTotalMs - d).clamp(0, remainingTotalMs),
      nextType: nextType,
      nextDurationMs: nextDurationMs,
      nextTargetReps: nextTargetReps,
      targetReps: targetReps,
      completedReps: completed,
      repElapsedMs: repElapsed,
      repMs: repMs,
    );
  }
}
