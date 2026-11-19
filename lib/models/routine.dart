// 순수 Dart 모델. Flutter를 import하지 않는다 (docs/05_기술_설계.md 8장).

/// 운동 구간이 끝나는 조건 (docs/02_기능_명세.md 3장)
enum EndCondition { time, reps }

/// 횟수 모드 음성 안내 방식 (docs/02_기능_명세.md 3.3절)
enum CueStyle { numbersOnly, actionAndNumbers, beepOnly }

/// 횟수 모드 템포: 내려가기 → 멈춤 → 올라오기 (docs/02_기능_명세.md 3.2절)
class Tempo {
  /// 값 검증은 [Routine.normalized]에서 한다. 저장 파일이 손상돼도
  /// 디버그 빌드에서 바로 죽지 않도록 여기서는 assert를 두지 않는다.
  const Tempo({required this.downMs, required this.holdMs, required this.upMs});

  final int downMs;
  final int holdMs;
  final int upMs;

  int get repMs => downMs + holdMs + upMs;

  static const slow = Tempo(downMs: 3000, holdMs: 1000, upMs: 2000);
  static const normal = Tempo(downMs: 2000, holdMs: 0, upMs: 1000);
  static const fast = Tempo(downMs: 1000, holdMs: 0, upMs: 1000);

  /// `2-0-1` 같은 표기
  String get label => '${_sec(downMs)}-${_sec(holdMs)}-${_sec(upMs)}';

  static String _sec(int ms) =>
      ms % 1000 == 0 ? '${ms ~/ 1000}' : (ms / 1000).toStringAsFixed(1);

  @override
  bool operator ==(Object other) =>
      other is Tempo &&
      other.downMs == downMs &&
      other.holdMs == holdMs &&
      other.upMs == upMs;

  @override
  int get hashCode => Object.hash(downMs, holdMs, upMs);
}

/// 루틴 하나 (docs/05_기술_설계.md 5.2절). 시간은 모두 밀리초.
class Routine {
  const Routine({
    required this.id,
    required this.name,
    this.isPreset = false,
    this.endCondition = EndCondition.time,
    this.prepMs = 10000,
    this.workMs = 40000,
    this.targetReps = 12,
    this.tempo = Tempo.normal,
    this.restMs = 20000,
    this.rounds = 8,
    this.sets = 1,
    this.setRestMs = 60000,
    this.skipLastRest = true,
    this.cueStyle = CueStyle.numbersOnly,
  });

  final String id;
  final String name;
  final bool isPreset;
  final EndCondition endCondition;
  final int prepMs;
  final int workMs;
  final int targetReps;
  final Tempo tempo;
  final int restMs;
  final int rounds;

  /// 시간 모드에서만 쓴다. 횟수 모드에서는 항상 1로 취급한다 (docs/02 2.5절).
  final int sets;
  final int setRestMs;
  final bool skipLastRest;
  final CueStyle cueStyle;

  bool get isReps => endCondition == EndCondition.reps;

  /// 실제로 적용되는 세트 수
  int get effectiveSets => isReps ? 1 : sets;

  /// 운동 구간 하나의 길이
  int get workDurationMs => isReps ? targetReps * tempo.repMs : workMs;

  /// 모든 값을 허용 범위 안으로 맞춘 사본 (docs/02_기능_명세.md 2.1절, 3.2절).
  /// 편집 화면에서 범위를 막더라도, 파일에서 읽은 값이 손상됐을 수 있으므로
  /// 엔진은 항상 이 값을 쓴다.
  Routine normalized() => Routine(
    id: id,
    name: name,
    isPreset: isPreset,
    endCondition: endCondition,
    prepMs: prepMs.clamp(0, RoutineLimits.maxPrepMs),
    workMs: workMs.clamp(RoutineLimits.minWorkMs, RoutineLimits.maxWorkMs),
    targetReps: targetReps.clamp(1, RoutineLimits.maxReps),
    tempo: Tempo(
      downMs: tempo.downMs.clamp(
        RoutineLimits.minTempoMs,
        RoutineLimits.maxTempoMs,
      ),
      holdMs: tempo.holdMs.clamp(0, RoutineLimits.maxTempoMs),
      upMs: tempo.upMs.clamp(
        RoutineLimits.minTempoMs,
        RoutineLimits.maxTempoMs,
      ),
    ),
    restMs: restMs.clamp(0, RoutineLimits.maxRestMs),
    rounds: rounds.clamp(1, RoutineLimits.maxRounds),
    sets: sets.clamp(1, RoutineLimits.maxSets),
    setRestMs: setRestMs.clamp(0, RoutineLimits.maxSetRestMs),
    skipLastRest: skipLastRest,
    cueStyle: cueStyle,
  );
}

/// 설정 항목 범위 (docs/02_기능_명세.md 2.1절, 3.2절)
abstract final class RoutineLimits {
  static const maxPrepMs = 60 * 1000;
  static const minWorkMs = 5 * 1000;
  static const maxWorkMs = (99 * 60 + 59) * 1000;
  static const maxReps = 100;
  static const minTempoMs = 500;
  static const maxTempoMs = 5000;
  static const maxRestMs = (99 * 60 + 59) * 1000;
  static const maxRounds = 99;
  static const maxSets = 20;
  static const maxSetRestMs = 30 * 60 * 1000;
}
