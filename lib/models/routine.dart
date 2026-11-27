// 순수 Dart 모델. Flutter를 import하지 않는다 (docs/05_기술_설계.md 8장).

/// 운동 구간이 끝나는 조건 (docs/02_기능_명세.md 3장)
enum EndCondition { time, reps }

/// 횟수 모드 음성 안내 방식 (docs/02_기능_명세.md 3.3절)
enum CueStyle { numbersOnly, beepOnly }

/// 횟수 모드 템포: 1회에 걸리는 시간 (docs/02_기능_명세.md 3.2절).
/// 운동마다 올리기·내리기 순서가 달라 동작은 나누지 않는다.
class Tempo {
  /// 값 검증은 [Routine.normalized]에서 한다. 저장 파일이 손상돼도
  /// 디버그 빌드에서 바로 죽지 않도록 여기서는 assert를 두지 않는다.
  const Tempo(this.repMs);

  final int repMs;

  static const slow = Tempo(6000);
  static const normal = Tempo(3000);
  static const fast = Tempo(2000);

  /// `3`, `2.5` 같은 초 표기 (단위는 화면에서 붙인다)
  String get seconds => repMs % 1000 == 0
      ? '${repMs ~/ 1000}'
      : (repMs / 1000).toStringAsFixed(1);

  @override
  bool operator ==(Object other) => other is Tempo && other.repMs == repMs;

  @override
  int get hashCode => repMs.hashCode;
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

  Routine copyWith({
    String? id,
    String? name,
    bool? isPreset,
    EndCondition? endCondition,
    int? prepMs,
    int? workMs,
    int? targetReps,
    Tempo? tempo,
    int? restMs,
    int? rounds,
    int? sets,
    int? setRestMs,
    bool? skipLastRest,
    CueStyle? cueStyle,
  }) => Routine(
    id: id ?? this.id,
    name: name ?? this.name,
    isPreset: isPreset ?? this.isPreset,
    endCondition: endCondition ?? this.endCondition,
    prepMs: prepMs ?? this.prepMs,
    workMs: workMs ?? this.workMs,
    targetReps: targetReps ?? this.targetReps,
    tempo: tempo ?? this.tempo,
    restMs: restMs ?? this.restMs,
    rounds: rounds ?? this.rounds,
    sets: sets ?? this.sets,
    setRestMs: setRestMs ?? this.setRestMs,
    skipLastRest: skipLastRest ?? this.skipLastRest,
    cueStyle: cueStyle ?? this.cueStyle,
  );

  /// 저장할 때 비교용 (이름 공백 정리 등은 편집 화면에서)
  bool sameSettingsAs(Routine o) {
    final a = toJson()..remove('id'), b = o.toJson()..remove('id');
    return a.toString() == b.toString();
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'isPreset': isPreset,
    'endCondition': endCondition.name,
    'prepMs': prepMs,
    'workMs': workMs,
    'targetReps': targetReps,
    'tempo': {'repMs': tempo.repMs},
    'restMs': restMs,
    'rounds': rounds,
    'sets': sets,
    'setRestMs': setRestMs,
    'skipLastRest': skipLastRest,
    'cueStyle': cueStyle.name,
  };

  /// 알 수 없는 값이나 빠진 값은 기본값으로 채운다. 범위는 [normalized]가 맞춘다.
  factory Routine.fromJson(Map<String, Object?> j) {
    const d = Routine(id: '', name: '');
    int i(String k, int def) => (j[k] as num?)?.toInt() ?? def;
    final t = (j['tempo'] as Map?)?.cast<String, Object?>() ?? const {};
    // 1.3.0까지는 내려가기·멈춤·올라오기를 따로 저장했다. 합이 1회 시간이다.
    final legacy = ['downMs', 'holdMs', 'upMs'].map((k) => t[k] as num?);
    final repMs =
        (t['repMs'] as num?)?.toInt() ??
        (legacy.any((v) => v != null)
            ? legacy.fold<int>(0, (a, v) => a + (v?.toInt() ?? 0))
            : d.tempo.repMs);
    T byName<T extends Enum>(List<T> values, Object? v, T def) =>
        values.where((e) => e.name == v).firstOrNull ?? def;
    return Routine(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      isPreset: j['isPreset'] as bool? ?? false,
      endCondition: byName(
        EndCondition.values,
        j['endCondition'],
        d.endCondition,
      ),
      prepMs: i('prepMs', d.prepMs),
      workMs: i('workMs', d.workMs),
      targetReps: i('targetReps', d.targetReps),
      tempo: Tempo(repMs),
      restMs: i('restMs', d.restMs),
      rounds: i('rounds', d.rounds),
      sets: i('sets', d.sets),
      setRestMs: i('setRestMs', d.setRestMs),
      skipLastRest: j['skipLastRest'] as bool? ?? d.skipLastRest,
      cueStyle: byName(CueStyle.values, j['cueStyle'], d.cueStyle),
    );
  }

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
      tempo.repMs.clamp(RoutineLimits.minRepMs, RoutineLimits.maxRepMs),
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
  static const maxPrepMs = 10 * 60 * 1000;
  static const minWorkMs = 5 * 1000;
  static const maxWorkMs = (99 * 60 + 59) * 1000;
  static const maxReps = 100;
  static const minRepMs = 1000;
  static const maxRepMs = 15000;
  static const maxRestMs = (99 * 60 + 59) * 1000;
  static const maxRounds = 99;
  static const maxSets = 20;
  static const maxSetRestMs = 30 * 60 * 1000;
  static const maxNameLength = 20;
}
