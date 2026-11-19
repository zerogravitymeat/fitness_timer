import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_timer/engine/cue.dart';
import 'package:health_timer/engine/segment.dart';
import 'package:health_timer/engine/tempo_clock.dart';
import 'package:health_timer/engine/timer_core.dart';
import 'package:health_timer/models/presets.dart';
import 'package:health_timer/models/routine.dart';

class FakeClock {
  int now = 1000000; // 0이 아닌 값에서 시작해도 동작해야 한다
  int call() => now;
}

/// [ms]만큼 [step] 간격으로 시간을 흘리며 tick을 부른다.
List<EngineEvent> run(
  TimerCore core,
  FakeClock clock,
  int ms, {
  int step = 10,
}) {
  final events = <EngineEvent>[];
  var left = ms;
  while (left > 0) {
    final d = left < step ? left : step;
    clock.now += d;
    left -= d;
    events.addAll(core.tick());
  }
  return events;
}

Iterable<String?> speeches(List<EngineEvent> e) =>
    e.whereType<CueDue>().map((c) => c.cue.speech).where((s) => s != null);

void main() {
  late FakeClock clock;
  setUp(() => clock = FakeClock());

  group('전체 진행', () {
    test('타바타를 끝까지: 구간 16개, 총 4분, 무료 운동 1회 차감, 건너뛴 알림 없음', () {
      final core = TimerCore(routine: Presets.tabata, clock: clock.call);
      final events = [...core.start(), ...run(core, clock, 240000 + 100)];

      expect(events.whereType<SegmentStarted>().length, 16);
      final fin = events.whereType<Finished>().single;
      expect(fin.totalActiveMs, 240000);
      expect(fin.stopped, isFalse);
      expect(fin.cue.speech, '운동 완료. 총 4분');
      expect(events.whereType<TrialCountable>().length, 1);
      expect(core.skippedCues, 0);
      expect(core.status, RunStatus.finished);

      // 알림 지연은 tick 간격(10ms) 이내
      final lates = events.whereType<CueDue>().map((c) => c.lateMs);
      expect(lates.every((l) => l >= 0 && l < 10), isTrue);
    });

    test('첫 알림은 시작하자마자 나온다', () {
      final core = TimerCore(routine: Presets.tabata, clock: clock.call);
      final events = core.start();
      expect(events.first, isA<SegmentStarted>());
      expect(speeches(events), ['준비하세요']);
    });

    test('기기가 5초 멈췄다 깨어나도 구간 전환은 모두 처리하고, 오래된 알림은 소리 내지 않는다', () {
      final core = TimerCore(routine: Presets.tabata, clock: clock.call);
      core.start();
      run(core, clock, 8000);
      clock.now += 5000; // 준비(10초)가 끝나고 운동 3초째
      final events = core.tick();
      expect(
        events.whereType<SegmentStarted>().single.segment.type,
        SegmentType.work,
      );
      expect(core.snapshot().segmentElapsedMs, 3000);
      expect(speeches(events), isNot(contains('운동 시작'))); // 3초 늦은 시작 안내는 버림
      expect(core.skippedCues, greaterThan(0));
    });
  });

  group('일시정지', () {
    test('일시정지한 시간은 진행 시간과 무료 운동 차감 기준에서 빠진다', () {
      final core = TimerCore(routine: Presets.hiit, clock: clock.call);
      core.start();
      run(core, clock, 30000);
      core.pause();
      clock.now += 100000; // 100초 쉼
      expect(core.tick(), isEmpty);
      expect(core.activeMs, 30000);

      core.resume();
      final before = run(core, clock, 29000);
      expect(before.whereType<TrialCountable>(), isEmpty);
      final after = run(core, clock, 2000);
      expect(after.whereType<TrialCountable>().length, 1);
      expect(core.activeMs, 61000);
    });

    test('60초 전에 중단하면 무료 운동을 차감하지 않는다', () {
      final core = TimerCore(routine: Presets.hiit, clock: clock.call);
      final events = [
        ...core.start(),
        ...run(core, clock, 59000),
        ...core.stop(),
      ];
      expect(events.whereType<TrialCountable>(), isEmpty);
      final fin = events.whereType<Finished>().single;
      expect(fin.stopped, isTrue);
      expect(fin.totalActiveMs, 59000);
    });

    test('횟수 모드: 재개하면 현재 회차를 처음부터', () {
      final core = TimerCore(routine: Presets.strength, clock: clock.call);
      core.start();
      run(core, clock, 10000 + 7000); // 준비 10초 + 운동 7초 = 2회 완료, 3회차 1초째
      var snap = core.snapshot();
      expect(snap.tempo!.completedReps, 2);
      expect(snap.tempo!.repElapsedMs, 1000);

      core.pause();
      clock.now += 20000;
      final events = core.resume();
      snap = core.snapshot();
      expect(snap.tempo!.completedReps, 2);
      expect(snap.tempo!.repElapsedMs, 0);
      expect(snap.tempo!.phase, TempoPhase.down);
      // 내려가기 신호를 다시 내고, 이미 읽은 "둘"은 반복하지 않는다
      final cues = events.whereType<CueDue>().map((e) => e.cue).toList();
      expect(cues.single.sound, CueSound.low);
      expect(cues.single.speech, isNull);
    });
  });

  group('진행 중 조작', () {
    test('다음: 운동 중 누르면 바로 휴식 시작', () {
      final core = TimerCore(routine: Presets.tabata, clock: clock.call);
      core.start();
      run(core, clock, 15000); // 운동 5초째
      final events = core.next();
      expect(
        events.whereType<SegmentStarted>().single.segment.type,
        SegmentType.rest,
      );
      expect(speeches(events), ['휴식 10초']);
      expect(core.snapshot().segmentElapsedMs, 0);
    });

    test('다음: 마지막 구간에서 누르면 완료', () {
      const r = Routine(id: 'a', name: 'a', prepMs: 0, rounds: 1);
      final core = TimerCore(routine: r, clock: clock.call);
      core.start();
      run(core, clock, 5000);
      final fin = core.next().whereType<Finished>().single;
      expect(fin.stopped, isFalse);
      expect(fin.totalActiveMs, 5000);
    });

    test('이전: 3초 이내면 이전 구간, 3초 넘으면 현재 구간 처음부터', () {
      final core = TimerCore(routine: Presets.tabata, clock: clock.call);
      core.start();
      run(core, clock, 12000); // 운동 2초째
      var e = core.prev();
      expect(
        e.whereType<SegmentStarted>().single.segment.type,
        SegmentType.prep,
      );

      run(core, clock, 5000); // 준비 5초째
      e = core.prev();
      final started = e.whereType<SegmentStarted>().single;
      expect(started.index, 0);
      expect(core.snapshot().segmentElapsedMs, 0);
    });

    test('휴식 +10초: 구간이 늘어나고 카운트다운도 다시 계획된다', () {
      final core = TimerCore(routine: Presets.tabata, clock: clock.call);
      core.start();
      run(core, clock, 10000 + 20000 + 2000); // 첫 휴식 2초째
      expect(core.snapshot().segment!.type, SegmentType.rest);
      core.addRest(10000);
      expect(core.snapshot().segmentDurationMs, 20000);

      final e = run(core, clock, 17500);
      // 원래 7·8·9초였던 카운트다운이 17·18·19초로
      expect(speeches(e), containsAllInOrder(['10초 남았습니다', '3', '2', '1']));
      expect(e.whereType<SegmentStarted>(), isEmpty);
      final e2 = run(core, clock, 600);
      expect(
        e2.whereType<SegmentStarted>().single.segment.type,
        SegmentType.work,
      );
    });

    test('휴식 +10초는 운동 구간에서는 무시', () {
      final core = TimerCore(routine: Presets.tabata, clock: clock.call);
      core.start();
      run(core, clock, 12000);
      core.addRest(10000);
      expect(core.snapshot().segmentDurationMs, 20000);
    });

    test('일시정지 중 다음 → 재개하면 새 구간 시작 안내', () {
      final core = TimerCore(routine: Presets.tabata, clock: clock.call);
      core.start();
      run(core, clock, 15000);
      core.pause();
      expect(core.next().whereType<SegmentStarted>(), hasLength(1));
      expect(speeches(core.resume()), ['휴식 10초']);
    });
  });

  test('스냅샷: 남은 전체 시간', () {
    final core = TimerCore(routine: Presets.tabata, clock: clock.call);
    expect(core.snapshot().remainingTotalMs, 240000);
    core.start();
    run(core, clock, 15000);
    final s = core.snapshot();
    expect(s.segmentRemainingMs, 15000);
    expect(s.remainingTotalMs, 225000);
    expect(s.totalActiveMs, 15000);
  });

  test('engine/과 models/는 Flutter를 import하지 않는다 (docs/05 8장)', () {
    final files = [
      ...Directory('lib/engine').listSync(),
      ...Directory('lib/models').listSync(),
    ].whereType<File>().where((f) => f.path.endsWith('.dart'));
    expect(files, isNotEmpty);
    for (final f in files) {
      expect(
        f.readAsStringSync(),
        isNot(contains('package:flutter')),
        reason: f.path,
      );
    }
  });

  // ── 검토에서 찾은 버그의 재발 방지 + 빠져 있던 조합 ──────────────

  group('일시정지 상태에서의 조작', () {
    test('일시정지 → 중단: 오류 없이 끝나고 "운동 종료"만 알린다', () {
      final core = TimerCore(routine: Presets.tabata, clock: clock.call);
      core.start();
      run(core, clock, 25000);
      core.pause();
      clock.now += 60000; // 일시정지 시간은 총 시간에서 빠진다
      final fin = core.stop().whereType<Finished>().single;
      expect(fin.stopped, isTrue);
      expect(fin.totalActiveMs, 25000);
      expect(fin.cue.speech, '운동 종료');
      expect(fin.cue.sound, isNull);
      expect(core.status, RunStatus.finished);
    });

    test('끝까지 했을 때만 완료음 + 총 시간', () {
      final core = TimerCore(routine: Presets.tabata, clock: clock.call);
      core.start();
      final fin = run(core, clock, 240000).whereType<Finished>().single;
      expect(fin.cue.sound, CueSound.done);
      expect(fin.cue.speech, '운동 완료. 총 4분');
    });

    test('일시정지 → 휴식 +10초 → 재개', () {
      final core = TimerCore(routine: Presets.tabata, clock: clock.call);
      core.start();
      run(core, clock, 30000 + 3000); // 첫 휴식 3초째
      core.pause();
      core.addRest(10000);
      expect(core.snapshot().segmentDurationMs, 20000);
      expect(core.snapshot().segmentRemainingMs, 17000);
      core.resume();
      final e = run(core, clock, 17000);
      expect(speeches(e), ['10초 남았습니다', '3', '2', '1', '2라운드, 운동 시작']);
    });

    test('일시정지 → 이전 → 재개하면 이전 구간 시작 안내', () {
      final core = TimerCore(routine: Presets.tabata, clock: clock.call);
      core.start();
      run(core, clock, 31000); // 첫 휴식 1초째
      core.pause();
      final e = core.prev();
      expect(
        e.whereType<SegmentStarted>().single.segment.type,
        SegmentType.work,
      );
      expect(e.whereType<CueDue>(), isEmpty); // 일시정지 중에는 소리 없음
      expect(speeches(core.resume()), ['1라운드, 운동 시작']);
    });

    test('일시정지 중 tick은 아무것도 하지 않는다', () {
      final core = TimerCore(routine: Presets.tabata, clock: clock.call);
      core.start();
      core.pause();
      clock.now += 500000;
      expect(core.tick(), isEmpty);
      expect(core.snapshot().segmentElapsedMs, 0);
    });
  });

  group('횟수 모드에서의 조작', () {
    test('세트 완료(다음) → 세트 간 휴식 시작', () {
      final core = TimerCore(routine: Presets.strength, clock: clock.call);
      core.start();
      run(core, clock, 10000 + 8000); // 운동 8초째
      final e = core.next();
      expect(
        e.whereType<SegmentStarted>().single.segment.type,
        SegmentType.rest,
      );
      expect(speeches(e), ['1세트 완료, 휴식 1분 30초']);
    });

    test('이전: 운동 2초째면 준비로, 5초째면 1회차부터 다시', () {
      final core = TimerCore(routine: Presets.strength, clock: clock.call);
      core.start();
      run(core, clock, 12000);
      expect(
        core.prev().whereType<SegmentStarted>().single.segment.type,
        SegmentType.prep,
      );
      run(core, clock, 10000 + 5000);
      final e = core.prev();
      expect(e.whereType<SegmentStarted>().single.segment.isRepWork, isTrue);
      expect(core.snapshot().tempo!.completedReps, 0);
      expect(speeches(e), ['1세트, 12회 시작']);
    });

    test('동작 + 숫자: 재개하면 "내려가고"를 다시 읽는다', () {
      const r = Routine(
        id: 'a',
        name: 'a',
        endCondition: EndCondition.reps,
        targetReps: 10,
        rounds: 1,
        prepMs: 0,
        cueStyle: CueStyle.actionAndNumbers,
      );
      final core = TimerCore(routine: r, clock: clock.call);
      core.start();
      run(core, clock, 4000); // 2회차 1초째
      core.pause();
      clock.now += 5000;
      final cue = core.resume().whereType<CueDue>().single.cue;
      expect(cue.speech, '내려가고');
      expect(cue.sound, CueSound.low);
      // 이어서 다음 박자는 정상
      expect(speeches(run(core, clock, 3000)), ['올라오고', '둘, 내려가고']);
    });

    test('세트 간 휴식 중 이전(3초 이내) → 직전 운동 구간을 1회차부터', () {
      final core = TimerCore(routine: Presets.strength, clock: clock.call);
      core.start();
      run(core, clock, 10000 + 36000 + 1000); // 휴식 1초째
      final e = core.prev();
      expect(e.whereType<SegmentStarted>().single.segment.isRepWork, isTrue);
      expect(core.snapshot().tempo!.currentRep(12), 1);
    });
  });

  group('스냅샷은 tick 없이도 현재 시각을 반영', () {
    test('준비가 끝난 뒤 tick 전에 읽어도 운동 구간', () {
      final core = TimerCore(routine: Presets.tabata, clock: clock.call);
      core.start();
      clock.now += 15000;
      final s = core.snapshot();
      expect(s.segment!.type, SegmentType.work);
      expect(s.segmentIndex, 1);
      expect(s.segmentElapsedMs, 5000);
      expect(s.remainingTotalMs, 225000);
    });

    test('스냅샷은 상태를 바꾸지 않는다 (알림은 tick에서 그대로 나온다)', () {
      final core = TimerCore(routine: Presets.tabata, clock: clock.call);
      core.start();
      clock.now += 10000;
      core.snapshot();
      final e = core.tick();
      expect(e.whereType<SegmentStarted>(), hasLength(1));
      expect(speeches(e), contains('1라운드, 운동 시작'));
    });

    test('마지막 구간을 넘긴 시각이면 마지막 구간 끝에 머문다', () {
      const r = Routine(id: 'a', name: 'a', prepMs: 0, rounds: 1);
      final core = TimerCore(routine: r, clock: clock.call);
      core.start();
      clock.now += 100000;
      final s = core.snapshot();
      expect(s.segmentRemainingMs, 0);
      expect(s.remainingTotalMs, 0);
    });
  });

  group('손상된 루틴 값', () {
    test('템포 0ms, 목표 0회, 라운드 0이어도 죽지 않고 최소값으로 진행', () {
      const r = Routine(
        id: 'bad',
        name: 'bad',
        endCondition: EndCondition.reps,
        tempo: Tempo(downMs: 0, holdMs: -5, upMs: 0),
        targetReps: 0,
        rounds: 0,
        prepMs: -1000,
      );
      final core = TimerCore(routine: r, clock: clock.call);
      expect(
        core.routine.tempo,
        const Tempo(downMs: 500, holdMs: 0, upMs: 500),
      );
      expect(core.routine.targetReps, 1);
      expect(core.segments.length, 1); // 준비 없음, 운동 1개
      final events = [...core.start(), ...run(core, clock, 2000)];
      expect(events.whereType<Finished>().single.totalActiveMs, 1000);
    });

    test('운동 0초는 최소 5초로', () {
      const r = Routine(
        id: 'bad',
        name: 'bad',
        workMs: 0,
        rounds: 1,
        prepMs: 0,
      );
      expect(
        TimerCore(routine: r, clock: clock.call).segments.single.durationMs,
        5000,
      );
    });

    test('정상 범위 값은 그대로', () {
      for (final p in Presets.all) {
        final n = p.normalized();
        expect(
          (
            n.prepMs,
            n.workMs,
            n.targetReps,
            n.tempo,
            n.restMs,
            n.rounds,
            n.sets,
          ),
          (
            p.prepMs,
            p.workMs,
            p.targetReps,
            p.tempo,
            p.restMs,
            p.rounds,
            p.sets,
          ),
          reason: p.name,
        );
      }
    });
  });
}
