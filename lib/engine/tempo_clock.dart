import '../models/routine.dart';

/// 횟수 모드 운동 구간 안에서, 경과 시간이 몇 번째 회차의 어디쯤인지 계산한다.
class TempoPosition {
  const TempoPosition({
    required this.completedReps,
    required this.repElapsedMs,
  });

  /// 끝낸 회차 수 (0부터)
  final int completedReps;

  /// 지금 하고 있는 회차 (1부터). 목표 횟수를 다 채웠으면 목표 횟수.
  int currentRep(int targetReps) =>
      completedReps >= targetReps ? targetReps : completedReps + 1;

  /// 현재 회차 안에서 지난 시간 (템포 바 위치)
  final int repElapsedMs;
}

abstract final class TempoClock {
  static TempoPosition at(Tempo t, int targetReps, int elapsedMs) {
    final total = targetReps * t.repMs;
    final e = elapsedMs.clamp(0, total);
    if (e >= total) {
      return TempoPosition(completedReps: targetReps, repElapsedMs: t.repMs);
    }
    return TempoPosition(
      completedReps: e ~/ t.repMs,
      repElapsedMs: e % t.repMs,
    );
  }
}
