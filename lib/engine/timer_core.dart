import 'dart:math';

import '../models/routine.dart';
import '../models/workout.dart';
import 'cue.dart';
import 'cue_planner.dart';
import 'routine_compiler.dart';
import 'segment.dart';
import 'tempo_clock.dart';

// ───────────────────────── 이벤트 ─────────────────────────

sealed class EngineEvent {
  const EngineEvent();
}

class SegmentStarted extends EngineEvent {
  const SegmentStarted(this.index, this.segment);
  final int index;
  final Segment segment;
  @override
  String toString() => 'SegmentStarted($index, $segment)';
}

class CueDue extends EngineEvent {
  const CueDue(this.cue, {required this.segmentIndex, required this.lateMs});
  final Cue cue;
  final int segmentIndex;

  /// 예정 시각보다 늦은 정도
  final int lateMs;
  @override
  String toString() => 'CueDue($cue, late=$lateMs)';
}

/// 실제 진행 시간(일시정지 제외)이 기준을 넘은 순간 한 번 (docs/02 10.2절)
class TrialCountable extends EngineEvent {
  const TrialCountable();
  @override
  String toString() => 'TrialCountable';
}

class Finished extends EngineEvent {
  const Finished({
    required this.totalActiveMs,
    required this.stopped,
    required this.cue,
  });
  final int totalActiveMs;

  /// 사용자가 중간에 끝냈으면 true
  final bool stopped;
  final Cue cue;
  @override
  String toString() => 'Finished(${totalActiveMs}ms, stopped=$stopped)';
}

// ───────────────────────── 상태 ─────────────────────────

enum RunStatus { idle, running, paused, finished }

/// 화면과 알림 영역에 보여줄 현재 상태
class EngineSnapshot {
  const EngineSnapshot({
    required this.status,
    required this.segmentIndex,
    required this.segmentCount,
    required this.segment,
    required this.segmentElapsedMs,
    required this.segmentDurationMs,
    required this.totalActiveMs,
    required this.remainingTotalMs,
    this.tempo,
  });

  final RunStatus status;
  final int segmentIndex;
  final int segmentCount;
  final Segment? segment;
  final int segmentElapsedMs;
  final int segmentDurationMs;
  final int totalActiveMs;
  final int remainingTotalMs;

  /// 횟수 모드 운동 구간에서만 값이 있다.
  final TempoPosition? tempo;

  int get segmentRemainingMs => max(0, segmentDurationMs - segmentElapsedMs);
}

/// 이어하기용 저장 상태 (docs/02_기능_명세.md 7장, docs/05 5.3절).
/// 구간 위치와 진행 시간만 저장하고, 구간 목록은 루틴에서 다시 만든다.
class EngineCheckpoint {
  const EngineCheckpoint({
    required this.segmentIndex,
    required this.segmentElapsedMs,
    required this.extraMs,
    required this.totalActiveMs,
    required this.trialCounted,
  });

  final int segmentIndex;
  final int segmentElapsedMs;

  /// 휴식 +10초로 늘어난 시간
  final int extraMs;
  final int totalActiveMs;
  final bool trialCounted;

  Map<String, Object?> toJson() => {
    'segmentIndex': segmentIndex,
    'segmentElapsedMs': segmentElapsedMs,
    'extraMs': extraMs,
    'totalActiveMs': totalActiveMs,
    'trialCounted': trialCounted,
  };

  factory EngineCheckpoint.fromJson(Map<String, Object?> j) {
    int i(String k) => (j[k] as num?)?.toInt() ?? 0;
    return EngineCheckpoint(
      segmentIndex: i('segmentIndex'),
      segmentElapsedMs: i('segmentElapsedMs'),
      extraMs: i('extraMs'),
      totalActiveMs: i('totalActiveMs'),
      trialCounted: j['trialCounted'] as bool? ?? false,
    );
  }
}

// ───────────────────────── 엔진 ─────────────────────────

/// 시간 진행의 핵심. 순수 Dart이며 시계를 주입받는다 (docs/05_기술_설계.md 3장).
///
/// - [clock]은 단조 증가하는 밀리초 값을 돌려줘야 한다 (실제로는 `Stopwatch`).
/// - 모든 명령은 그 사이에 생긴 이벤트 목록을 돌려준다.
/// - 일시정지한 시간은 진행 시간에 들어가지 않는다.
class TimerCore {
  /// 루틴 하나
  TimerCore({
    required Routine routine,
    required int Function() clock,
    CueSettings settings = const CueSettings(),
    int trialThresholdMs = 60000,
    int staleCueMs = 1000,
    int prevRestartThresholdMs = 3000,
  }) : this.workout(
         workout: Workout.single(routine),
         clock: clock,
         settings: settings,
         trialThresholdMs: trialThresholdMs,
         staleCueMs: staleCueMs,
         prevRestartThresholdMs: prevRestartThresholdMs,
       );

  /// 루틴 하나 또는 코스 (docs/02 8-1장)
  TimerCore.workout({
    required Workout workout,
    required this.clock,
    this.settings = const CueSettings(),
    this.trialThresholdMs = 60000,
    this.staleCueMs = 1000,
    this.prevRestartThresholdMs = 3000,
  }) : workout = workout.normalized(),
       // 휴식 길이도 허용 범위로 맞춘 값으로 펼친다 (파일·전달 값이 손상됐을 수 있다)
       segments = RoutineCompiler.compileWorkout(workout.normalized());

  /// 허용 범위로 맞춘 운동 ([Workout.normalized])
  final Workout workout;

  /// 첫 루틴 (루틴 하나일 때는 그 루틴)
  Routine get routine => workout.routines.first;

  /// 구간이 속한 루틴
  Routine routineOf(Segment s) => workout.routines[s.part];

  final CueSettings settings;
  final List<Segment> segments;

  /// 무료 운동 1회로 셀 진행 시간
  final int trialThresholdMs;

  /// 이보다 늦은 알림은 소리 내지 않고 버린다 (기기가 잠깐 멈췄다 깨어난 경우)
  final int staleCueMs;

  /// "이전"을 눌렀을 때 이보다 많이 지났으면 현재 구간을 처음부터 다시 한다
  final int prevRestartThresholdMs;

  /// 단조 증가 밀리초 시계
  final int Function() clock;

  RunStatus _status = RunStatus.idle;
  int _clockStart = 0;
  int _pausedAccum = 0;
  int _pausedAt = 0;
  int _finishedActive = 0;

  int _index = 0;
  int _segStart = 0;
  int _extraMs = 0;
  List<Cue> _cues = const [];
  int _cuePtr = 0;
  bool _trialSent = false;
  int _skippedCues = 0;

  RunStatus get status => _status;
  int get skippedCues => _skippedCues;

  int get activeMs => switch (_status) {
    RunStatus.idle => 0,
    RunStatus.running => clock() - _clockStart - _pausedAccum,
    RunStatus.paused => _pausedAt - _clockStart - _pausedAccum,
    RunStatus.finished => _finishedActive,
  };

  int get _curDuration => segments[_index].durationMs + _extraMs;

  // ── 명령 ─────────────────────────────────────

  List<EngineEvent> start() {
    if (_status != RunStatus.idle) return [];
    _clockStart = clock();
    _status = RunStatus.running;
    final events = <EngineEvent>[];
    _enter(0, 0, events);
    if (_status == RunStatus.running) events.addAll(tick());
    return events;
  }

  /// 저장해 둔 위치에서 **일시정지 상태로** 다시 시작한다 (이어하기).
  /// 사용자가 재개를 눌러야 진행된다 (docs/03 D1).
  List<EngineEvent> restore(EngineCheckpoint c) {
    if (_status != RunStatus.idle) return [];
    if (segments.isEmpty || c.segmentIndex >= segments.length) return start();
    final i = c.segmentIndex.clamp(0, segments.length - 1);
    final extra = segments[i].isRest ? max(0, c.extraMs) : 0;
    final dur = segments[i].durationMs + extra;
    final segElapsed = min(max(0, c.segmentElapsedMs), max(0, dur - 1));
    final total = max(c.totalActiveMs, segElapsed);

    final now = clock();
    _clockStart = now - total;
    _pausedAccum = 0;
    _pausedAt = now;
    _status = RunStatus.paused;
    _trialSent = c.trialCounted;

    final events = <EngineEvent>[];
    _enter(i, total - segElapsed, events);
    _extraMs = extra;
    _cues = _plan(i);
    _cuePtr = _firstCueAfter(segElapsed);
    return events;
  }

  /// 지금 상태를 저장용으로 (이어하기)
  EngineCheckpoint get checkpoint {
    final total = activeMs;
    return EngineCheckpoint(
      segmentIndex: _index,
      segmentElapsedMs: max(0, total - _segStart),
      extraMs: _extraMs,
      totalActiveMs: total,
      trialCounted: _trialSent,
    );
  }

  List<EngineEvent> tick() {
    if (_status != RunStatus.running) return [];
    final now = activeMs;
    final events = <EngineEvent>[];

    while (_status == RunStatus.running) {
      final elapsed = now - _segStart;
      final dur = _curDuration;
      final limit = min(elapsed, dur);
      while (_cuePtr < _cues.length && _cues[_cuePtr].offsetMs <= limit) {
        final c = _cues[_cuePtr++];
        final late = now - (_segStart + c.offsetMs);
        if (late <= staleCueMs) {
          events.add(CueDue(c, segmentIndex: _index, lateMs: late));
        } else {
          _skippedCues++;
        }
      }
      if (elapsed >= dur) {
        _enter(_index + 1, _segStart + dur, events);
      } else {
        break;
      }
    }

    if (!_trialSent && min(now, activeMs) >= trialThresholdMs) {
      _trialSent = true;
      events.add(const TrialCountable());
    }
    return events;
  }

  List<EngineEvent> pause() {
    if (_status != RunStatus.running) return [];
    final events = tick();
    if (_status == RunStatus.running) {
      _pausedAt = clock();
      _status = RunStatus.paused;
    }
    return events;
  }

  /// 횟수 모드 운동 중이면 현재 회차를 처음(내려가기)부터 다시 한다 (docs/02 5장).
  List<EngineEvent> resume() {
    if (_status != RunStatus.paused) return [];
    _pausedAccum += clock() - _pausedAt;
    _status = RunStatus.running;
    final events = <EngineEvent>[];

    final seg = segments[_index];
    if (seg.isRepWork) {
      final routine = routineOf(seg);
      final repMs = routine.tempo.repMs;
      final now = activeMs;
      final floored = ((now - _segStart) ~/ repMs) * repMs;
      _segStart = now - floored;
      _cuePtr = _firstCueAfter(floored);
      if (floored > 0) {
        // 회차 시작 신호를 다시 낸다 (이미 낸 회차 숫자는 반복하지 않는다)
        events.add(
          CueDue(
            Cue(
              offsetMs: floored,
              kind: CueKind.tempoPhase,
              tempoPhase: TempoPhase.down,
              sound: CueSound.low,
              speech: routine.cueStyle == CueStyle.actionAndNumbers
                  ? '내려가고'
                  : null,
            ),
            segmentIndex: _index,
            lateMs: 0,
          ),
        );
      } else {
        _cuePtr = 0; // 첫 회차였다면 구간 시작 알림부터 다시
      }
    }
    events.addAll(tick());
    return events;
  }

  /// 현재 구간을 끝내고 다음 구간으로 (횟수 모드에서는 "세트 완료")
  List<EngineEvent> next() =>
      _jump((now, events) => _enter(_index + 1, now, events));

  /// 3초 넘게 지났으면 현재 구간을 처음부터, 아니면 이전 구간으로
  List<EngineEvent> prev() => _jump((now, events) {
    final elapsed = now - _segStart;
    final target = (elapsed > prevRestartThresholdMs || _index == 0)
        ? _index
        : _index - 1;
    _enter(target, now, events);
  });

  /// 휴식·세트 간 휴식 구간에서만 동작
  List<EngineEvent> addRest(int ms) {
    if (_status != RunStatus.running && _status != RunStatus.paused) {
      return [];
    }
    if (!segments[_index].isRest) return [];
    final events = tick();
    if (_status == RunStatus.finished) return events;
    _extraMs += ms;
    final elapsed = activeMs - _segStart;
    _cues = _plan(_index);
    _cuePtr = _firstCueAfter(elapsed);
    return events;
  }

  /// 사용자가 중간에 끝냄
  List<EngineEvent> stop() {
    if (_status != RunStatus.running && _status != RunStatus.paused) {
      return [];
    }
    final events = tick();
    if (_status == RunStatus.finished) return events;
    _finish(activeMs, stopped: true, events: events);
    return events;
  }

  EngineSnapshot snapshot() {
    final total = activeMs;
    if (_status == RunStatus.idle ||
        _status == RunStatus.finished ||
        segments.isEmpty) {
      return EngineSnapshot(
        status: _status,
        segmentIndex: _status == RunStatus.finished ? segments.length : 0,
        segmentCount: segments.length,
        segment: null,
        segmentElapsedMs: 0,
        segmentDurationMs: 0,
        totalActiveMs: total,
        remainingTotalMs: _status == RunStatus.idle
            ? RoutineCompiler.estimatedWorkoutMs(workout)
            : 0,
      );
    }
    // tick()이 아직 따라잡지 못했어도 현재 시각 기준 위치를 보여준다.
    // 상태는 바꾸지 않는다 (알림 발사는 tick()만 한다).
    var idx = _index;
    var segStart = _segStart;
    var dur = _curDuration;
    while (total - segStart >= dur && idx + 1 < segments.length) {
      segStart += dur;
      idx++;
      dur = segments[idx].durationMs;
    }
    final seg = segments[idx];
    final elapsed = min(total - segStart, dur);
    var remaining = dur - elapsed;
    for (var i = idx + 1; i < segments.length; i++) {
      remaining += segments[i].durationMs;
    }
    return EngineSnapshot(
      status: _status,
      segmentIndex: idx,
      segmentCount: segments.length,
      segment: seg,
      segmentElapsedMs: elapsed,
      segmentDurationMs: dur,
      totalActiveMs: total,
      remainingTotalMs: remaining,
      tempo: seg.isRepWork
          ? TempoClock.at(routineOf(seg).tempo, seg.targetReps!, elapsed)
          : null,
    );
  }

  // ── 내부 ─────────────────────────────────────

  List<EngineEvent> _jump(
    void Function(int now, List<EngineEvent> events) move,
  ) {
    if (_status != RunStatus.running && _status != RunStatus.paused) {
      return [];
    }
    final events = _status == RunStatus.running ? tick() : <EngineEvent>[];
    if (_status == RunStatus.finished) return events;
    move(activeMs, events);
    if (_status == RunStatus.running) events.addAll(tick());
    return events;
  }

  void _enter(int i, int startActive, List<EngineEvent> events) {
    if (i >= segments.length) {
      _finish(startActive, stopped: false, events: events);
      return;
    }
    _index = i;
    _segStart = startActive;
    _extraMs = 0;
    _cues = _plan(i);
    _cuePtr = 0;
    events.add(SegmentStarted(i, segments[i]));
  }

  void _finish(
    int totalActive, {
    required bool stopped,
    required List<EngineEvent> events,
  }) {
    _finishedActive = totalActive;
    _status = RunStatus.finished;
    events.add(
      Finished(
        totalActiveMs: totalActive,
        stopped: stopped,
        cue: CuePlanner.finished(totalActive, stopped: stopped),
      ),
    );
  }

  List<Cue> _plan(int i) => CuePlanner.plan(
    routineOf(segments[i]),
    segments[i],
    durationMs: _curDuration,
    settings: settings,
    announceName: workout.isCourse,
  );

  int _firstCueAfter(int offset) {
    var p = 0;
    while (p < _cues.length && _cues[p].offsetMs <= offset) {
      p++;
    }
    return p;
  }
}
