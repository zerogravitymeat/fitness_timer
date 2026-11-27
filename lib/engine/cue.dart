enum CueKind {
  segmentStart,
  countdown,
  halfway,
  tenSecondsLeft,
  repStart,
  repCompleted,
  secondTick,
  finished,
}

/// 비프음 종류 (docs/05_기술_설계.md 4.1절)
/// [tick]·[tock]은 1초 소리. 방향 지시등처럼 번갈아 내서 초가 구분되게 한다.
enum CueSound { low, high, tick, tock, short, long, done }

enum CueVibration { short, long, double }

/// 한 구간 안에서 [offsetMs] 시점에 낼 알림.
/// 같은 시점의 알림은 [CuePlanner]가 하나로 합친다.
class Cue {
  const Cue({
    required this.offsetMs,
    required this.kind,
    this.sound,
    this.vibration,
    this.speech,
    this.rep,
  });

  final int offsetMs;

  /// 대표 종류 (합쳐진 경우 먼저 추가된 것)
  final CueKind kind;
  final CueSound? sound;
  final CueVibration? vibration;
  final String? speech;

  /// [CueKind.repCompleted]: 끝낸 회차 (1부터)
  final int? rep;

  Cue mergeWith(Cue o) {
    assert(o.offsetMs == offsetMs);
    final speeches = [?speech, ?o.speech];
    return Cue(
      offsetMs: offsetMs,
      kind: kind,
      sound: sound ?? o.sound,
      vibration: vibration ?? o.vibration,
      speech: speeches.isEmpty ? null : speeches.join(', '),
      rep: rep ?? o.rep,
    );
  }

  @override
  String toString() =>
      'Cue(@$offsetMs ${kind.name}${sound != null ? ' ${sound!.name}' : ''}${speech != null ? ' "$speech"' : ''})';
}
