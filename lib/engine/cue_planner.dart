import '../models/routine.dart';
import 'cue.dart';
import 'cue_text.dart';
import 'segment.dart';
import 'tempo_clock.dart';

/// 앱 전체 알림 설정 중 계획에 영향을 주는 값 (docs/02_기능_명세.md 6.3절)
/// 소리·진동·음성 켜고 끄기는 계획이 아니라 재생하는 쪽에서 거른다.
class CueSettings {
  const CueSettings({
    this.countdownSeconds = 3,
    this.text = const KoreanCueText(),
  }) : assert(
         countdownSeconds == 0 ||
             countdownSeconds == 3 ||
             countdownSeconds == 5,
       );

  final int countdownSeconds;

  /// 음성 안내 언어
  final CueText text;
}

/// 구간마다 언제 무엇을 알릴지 계획한다 (docs/02_기능_명세.md 6장, 3.3절).
abstract final class CuePlanner {
  static const halfwayMinMs = 60000;
  static const tenSecondsMinRestMs = 20000;

  /// [durationMs]는 실제 구간 길이 (휴식 +10초가 반영된 값).
  /// [r]은 그 구간이 속한 루틴 (루틴 사이 휴식은 다음 루틴).
  /// [announceName]이 true면 루틴의 첫 운동과 루틴 사이 휴식에서 루틴 이름을 읽는다 (코스).
  static List<Cue> plan(
    Routine r,
    Segment seg, {
    required int durationMs,
    CueSettings settings = const CueSettings(),
    bool announceName = false,
  }) {
    final cues = <Cue>[];
    final text = settings.text;

    // ── 구간 시작
    cues.add(
      Cue(
        offsetMs: 0,
        kind: CueKind.segmentStart,
        sound: seg.type == SegmentType.prep ? null : CueSound.long,
        vibration: seg.type == SegmentType.prep ? null : CueVibration.long,
        speech: _startSpeech(
          text,
          r,
          seg,
          durationMs,
          announceName: announceName,
        ),
      ),
    );

    if (seg.isRepWork) {
      _planReps(text, r, seg, cues);
    } else {
      // ── 종료 전 카운트다운 (시간으로 끝나는 구간만)
      for (var k = settings.countdownSeconds; k >= 1; k--) {
        final at = durationMs - k * 1000;
        if (at > 0) {
          cues.add(
            Cue(
              offsetMs: at,
              kind: CueKind.countdown,
              sound: CueSound.short,
              vibration: CueVibration.short,
              speech: text.countdown(k),
            ),
          );
        }
      }
      if (seg.type == SegmentType.work && durationMs >= halfwayMinMs) {
        cues.add(
          Cue(
            offsetMs: durationMs ~/ 2,
            kind: CueKind.halfway,
            speech: text.halfway,
          ),
        );
      }
      if (seg.isRest && durationMs >= tenSecondsMinRestMs) {
        cues.add(
          Cue(
            offsetMs: durationMs - 10000,
            kind: CueKind.tenSecondsLeft,
            speech: text.tenSecondsLeft,
          ),
        );
      }
    }
    return _mergeSameOffset(cues);
  }

  static void _planReps(CueText text, Routine r, Segment seg, List<Cue> cues) {
    final t = r.tempo;
    final target = seg.targetReps!;
    final withSpeech = r.cueStyle != CueStyle.beepOnly;
    final withAction = r.cueStyle == CueStyle.actionAndNumbers;

    for (var i = 0; i < target; i++) {
      final base = i * t.repMs;
      var at = base;
      for (final (phase, dur) in TempoClock.phases(t)) {
        // 첫 회차의 내려가기는 구간 시작 알림(긴 비프)이 대신한다.
        if (!(i == 0 && phase == TempoPhase.down)) {
          cues.add(
            Cue(
              offsetMs: at,
              kind: CueKind.tempoPhase,
              tempoPhase: phase,
              sound: switch (phase) {
                TempoPhase.down => CueSound.low,
                TempoPhase.hold => CueSound.tick,
                TempoPhase.up => CueSound.high,
              },
              speech: !withAction
                  ? null
                  : switch (phase) {
                      TempoPhase.down => text.down,
                      TempoPhase.hold => null,
                      TempoPhase.up => text.up,
                    },
            ),
          );
        }
        at += dur;
      }

      // 회차 완료. 마지막 회차의 완료는 다음 구간 시작 알림이 대신한다.
      final done = i + 1;
      if (done < target) {
        cues.add(
          Cue(
            offsetMs: base + t.repMs,
            kind: CueKind.repCompleted,
            rep: done,
            speech: withSpeech ? text.repNumber(done) : null,
          ),
        );
      }
    }
  }

  static String? _startSpeech(
    CueText text,
    Routine r,
    Segment seg,
    int durationMs, {
    bool announceName = false,
  }) {
    switch (seg.type) {
      case SegmentType.prep:
        // 횟수 모드는 운동 시작 때 음성이 없으므로 여기서 미리 알린다
        return r.isReps
            ? [
                text.prepare,
                if (announceName) r.name,
                _reps(text, r, 1),
              ].join(', ')
            : text.prepare;
      case SegmentType.work:
        // 횟수 모드는 긴 비프만 낸다. 음성이 첫 회차와 겹치면
        // 사용자가 음성이 끝난 뒤에 움직여 회차가 하나씩 밀린다.
        if (seg.isRepWork) return null;
        final prefix = <String>[
          if (announceName && seg.isFirstWork) r.name,
          if (r.effectiveSets > 1 && seg.round == 1) text.setLabel(seg.set),
          if (r.rounds > 1) text.roundLabel(seg.round),
        ];
        return [...prefix, text.workStart].join(', ');
      case SegmentType.rest:
        // 횟수 모드의 휴식은 "세트 간 휴식"으로 안내하고 다음 세트를 미리 알린다 (docs/02 6.2절)
        return r.isReps
            ? [
                text.setDone(seg.round),
                text.rest(durationMs),
                text.nextReps(_reps(text, r, seg.round + 1)),
              ].join(', ')
            : text.rest(durationMs);
      case SegmentType.setRest:
        return '${text.setDone(seg.set)}, ${text.rest(durationMs)}';
      case SegmentType.courseRest:
        return [
          text.rest(durationMs),
          text.nextRoutine(r.name),
          if (r.isReps) _reps(text, r, 1),
        ].join(', ');
    }
  }

  /// 횟수 모드에서 곧 할 세트 안내. 예: "2세트 15회", 세트가 하나면 "15회"
  static String _reps(CueText text, Routine r, int round) =>
      text.reps(r.rounds > 1 ? round : null, r.targetReps);

  /// 루틴이 끝났을 때 알림. 끝까지 했으면 실제로 걸린 시간을 읽고,
  /// 사용자가 중간에 끝냈으면 "운동 종료"만 짧게 알린다 (docs/03 6장).
  static Cue finished(
    int totalActiveMs, {
    bool stopped = false,
    CueText text = const KoreanCueText(),
  }) => stopped
      ? Cue(offsetMs: 0, kind: CueKind.finished, speech: text.stopped)
      : Cue(
          offsetMs: 0,
          kind: CueKind.finished,
          sound: CueSound.done,
          vibration: CueVibration.double,
          speech: text.completed(totalActiveMs),
        );

  static List<Cue> _mergeSameOffset(List<Cue> cues) {
    final byOffset = <int, Cue>{};
    for (final c in cues) {
      byOffset.update(
        c.offsetMs,
        (prev) => prev.mergeWith(c),
        ifAbsent: () => c,
      );
    }
    final out = byOffset.values.toList()
      ..sort((a, b) => a.offsetMs.compareTo(b.offsetMs));
    return out;
  }
}
