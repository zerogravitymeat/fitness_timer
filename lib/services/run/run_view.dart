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
    this.tempoPhase,
    this.repElapsedMs,
    this.tempoDownMs,
    this.tempoHoldMs,
    this.tempoUpMs,
  });

  final RunStatus status;
  final String routineName;
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
  final TempoPhase? tempoPhase;
  final int? repElapsedMs;
  final int? tempoDownMs;
  final int? tempoHoldMs;
  final int? tempoUpMs;

  bool get isRepWork => targetReps != null;
  int get segmentRemainingMs =>
      (segmentDurationMs - segmentElapsedMs).clamp(0, segmentDurationMs);

  factory RunView.from(TimerCore core) {
    final s = core.snapshot();
    final r = core.routine;
    final seg = s.segment;
    final nextIdx = s.segmentIndex + 1;
    final next = seg != null && nextIdx < core.segments.length
        ? core.segments[nextIdx]
        : null;
    final tp = s.tempo;
    return RunView(
      status: s.status,
      routineName: r.name,
      isReps: r.isReps,
      rounds: r.rounds,
      sets: r.effectiveSets,
      segmentIndex: s.segmentIndex,
      segmentCount: s.segmentCount,
      segmentType: seg?.type,
      round: seg?.round ?? r.rounds,
      set: seg?.set ?? r.effectiveSets,
      segmentElapsedMs: s.segmentElapsedMs,
      segmentDurationMs: s.segmentDurationMs,
      totalActiveMs: s.totalActiveMs,
      remainingTotalMs: s.remainingTotalMs,
      nextType: next?.type,
      nextDurationMs: next?.durationMs,
      nextTargetReps: next?.targetReps,
      targetReps: seg?.targetReps,
      completedReps: tp?.completedReps,
      tempoPhase: tp?.phase,
      repElapsedMs: tp?.repElapsedMs,
      tempoDownMs: seg?.isRepWork == true ? r.tempo.downMs : null,
      tempoHoldMs: seg?.isRepWork == true ? r.tempo.holdMs : null,
      tempoUpMs: seg?.isRepWork == true ? r.tempo.upMs : null,
    );
  }

  Map<String, Object?> toMap() => {
    'status': status.name,
    'routineName': routineName,
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
    'tempoPhase': tempoPhase?.name,
    'repElapsedMs': repElapsedMs,
    'tempoDownMs': tempoDownMs,
    'tempoHoldMs': tempoHoldMs,
    'tempoUpMs': tempoUpMs,
  };

  factory RunView.fromMap(Map<Object?, Object?> m) {
    T? byName<T extends Enum>(List<T> values, Object? v) =>
        values.where((e) => e.name == v).firstOrNull;
    int i(String k) => (m[k] as num?)?.toInt() ?? 0;
    int? oi(String k) => (m[k] as num?)?.toInt();
    return RunView(
      status: byName(RunStatus.values, m['status']) ?? RunStatus.idle,
      routineName: m['routineName'] as String? ?? '',
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
      tempoPhase: byName(TempoPhase.values, m['tempoPhase']),
      repElapsedMs: oi('repElapsedMs'),
      tempoDownMs: oi('tempoDownMs'),
      tempoHoldMs: oi('tempoHoldMs'),
      tempoUpMs: oi('tempoUpMs'),
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
    TempoPhase? phase = tempoPhase;
    if (isRepWork && tempoDownMs != null) {
      final pos = TempoClock.at(
        Tempo(downMs: tempoDownMs!, holdMs: tempoHoldMs!, upMs: tempoUpMs!),
        targetReps!,
        e,
      );
      completed = pos.completedReps;
      repElapsed = pos.repElapsedMs;
      phase = pos.phase;
    }
    return RunView(
      status: status,
      routineName: routineName,
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
      tempoPhase: phase,
      repElapsedMs: repElapsed,
      tempoDownMs: tempoDownMs,
      tempoHoldMs: tempoHoldMs,
      tempoUpMs: tempoUpMs,
    );
  }
}
