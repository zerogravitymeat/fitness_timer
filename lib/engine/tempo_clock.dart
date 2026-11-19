import '../models/routine.dart';

enum TempoPhase { down, hold, up }

/// 횟수 모드 운동 구간 안에서, 경과 시간이 몇 번째 회차의 어느 동작인지 계산한다.
class TempoPosition {
  const TempoPosition({
    required this.completedReps,
    required this.phase,
    required this.phaseElapsedMs,
    required this.phaseDurationMs,
    required this.repElapsedMs,
  });

  /// 끝낸 회차 수 (0부터)
  final int completedReps;

  /// 지금 하고 있는 회차 (1부터). 목표 횟수를 다 채웠으면 목표 횟수.
  int currentRep(int targetReps) =>
      completedReps >= targetReps ? targetReps : completedReps + 1;

  final TempoPhase phase;
  final int phaseElapsedMs;
  final int phaseDurationMs;

  /// 현재 회차 안에서 지난 시간 (템포 바 위치)
  final int repElapsedMs;
}

abstract final class TempoClock {
  /// 0ms인 단계(예: 멈춤 0초)는 건너뛴 순서
  static List<(TempoPhase, int)> phases(Tempo t) => [
    (TempoPhase.down, t.downMs),
    if (t.holdMs > 0) (TempoPhase.hold, t.holdMs),
    (TempoPhase.up, t.upMs),
  ];

  static TempoPosition at(Tempo t, int targetReps, int elapsedMs) {
    final total = targetReps * t.repMs;
    final e = elapsedMs.clamp(0, total);
    if (e >= total) {
      return TempoPosition(
        completedReps: targetReps,
        phase: TempoPhase.up,
        phaseElapsedMs: t.upMs,
        phaseDurationMs: t.upMs,
        repElapsedMs: t.repMs,
      );
    }
    final completed = e ~/ t.repMs;
    final inRep = e % t.repMs;
    var acc = 0;
    for (final (phase, dur) in phases(t)) {
      if (inRep < acc + dur) {
        return TempoPosition(
          completedReps: completed,
          phase: phase,
          phaseElapsedMs: inRep - acc,
          phaseDurationMs: dur,
          repElapsedMs: inRep,
        );
      }
      acc += dur;
    }
    throw StateError('unreachable');
  }
}
