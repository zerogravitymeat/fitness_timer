import 'package:fitness_timer/engine/cue.dart';
import 'package:fitness_timer/engine/segment.dart';
import 'package:fitness_timer/engine/timer_core.dart';
import 'package:fitness_timer/models/presets.dart';
import 'package:flutter_test/flutter_test.dart';

List<EngineEvent> run(TimerCore core, void Function(int) advance, int ms) {
  final out = <EngineEvent>[];
  for (var t = 0; t < ms; t += 10) {
    advance(10);
    out.addAll(core.tick());
  }
  return out;
}

void main() {
  var now = 0;
  void advance(int ms) => now += ms;
  setUp(() => now = 500000);

  test('저장한 위치에서 일시정지 상태로 복원하고, 재개하면 이어서 진행', () {
    final a = TimerCore(routine: Presets.tabata, clock: () => now);
    a.start();
    run(a, advance, 10000 + 20000 + 4000); // 첫 휴식 4초째
    final cp = a.checkpoint;
    expect(cp.segmentIndex, 2);
    expect(cp.segmentElapsedMs, 4000);
    expect(cp.totalActiveMs, 34000);

    // 앱이 죽고 새 엔진에서 복원
    now = 9000000;
    final b = TimerCore(routine: Presets.tabata, clock: () => now);
    final events = b.restore(cp);
    expect(
      events.whereType<SegmentStarted>().single.segment.type,
      SegmentType.rest,
    );
    expect(events.whereType<CueDue>(), isEmpty); // 일시정지 상태라 소리 없음
    expect(b.status, RunStatus.paused);
    var s = b.snapshot();
    expect(
      (s.segmentIndex, s.segmentElapsedMs, s.totalActiveMs),
      (2, 4000, 34000),
    );

    now += 60000; // 복원 후 확인 창에서 1분 머뭇거림
    expect(b.snapshot().totalActiveMs, 34000);

    b.resume();
    final after = run(b, advance, 6000);
    final speeches = after
        .whereType<CueDue>()
        .map((e) => e.cue.speech)
        .whereType<String>();
    // 이미 지나간 "휴식 10초" 안내는 다시 나오지 않고, 남은 카운트다운부터
    expect(speeches.first, '3');
    expect(speeches, contains('2라운드, 운동 시작'));
    s = b.snapshot();
    expect(s.segment!.type, SegmentType.work);
  });

  test('휴식 +10초와 무료 운동 차감 여부도 복원', () {
    final a = TimerCore(routine: Presets.hiit, clock: () => now);
    a.start();
    run(a, advance, 10000 + 40000 + 15000); // 첫 휴식 15초째, 진행 65초
    a.addRest(10000);
    final cp = a.checkpoint;
    expect(cp.extraMs, 10000);
    expect(cp.trialCounted, isTrue);

    final b = TimerCore(routine: Presets.hiit, clock: () => now);
    b.restore(cp);
    expect(b.snapshot().segmentDurationMs, 30000);
    b.resume();
    expect(
      run(b, advance, 20000).whereType<TrialCountable>(),
      isEmpty,
    ); // 다시 차감하지 않음
  });

  test('횟수 모드: 복원 후 재개하면 현재 회차 처음부터', () {
    final a = TimerCore(routine: Presets.strength, clock: () => now);
    a.start();
    run(a, advance, 10000 + 7500); // 3회차 1.5초째
    final b = TimerCore(routine: Presets.strength, clock: () => now);
    b.restore(a.checkpoint);
    final cue = b.resume().whereType<CueDue>().single.cue;
    expect(cue.sound, CueSound.low);
    expect(b.snapshot().tempo!.completedReps, 2);
    expect(b.snapshot().tempo!.repElapsedMs, 0);
  });

  test('범위를 벗어난 저장값은 안전하게 처리', () {
    final b = TimerCore(routine: Presets.tabata, clock: () => now);
    b.restore(
      const EngineCheckpoint(
        segmentIndex: 999,
        segmentElapsedMs: 0,
        extraMs: 0,
        totalActiveMs: 0,
        trialCounted: false,
      ),
    );
    expect(b.status, RunStatus.running); // 처음부터 시작

    final c = TimerCore(routine: Presets.tabata, clock: () => now);
    c.restore(
      const EngineCheckpoint(
        segmentIndex: 1,
        segmentElapsedMs: 999999, // 구간보다 긴 값
        extraMs: 50000, // 운동 구간에는 +10초 없음
        totalActiveMs: 5,
        trialCounted: false,
      ),
    );
    final s = c.snapshot();
    expect(s.segmentDurationMs, 20000);
    expect(s.segmentElapsedMs, lessThan(20000));
  });

  test('checkpoint JSON 왕복', () {
    const cp = EngineCheckpoint(
      segmentIndex: 3,
      segmentElapsedMs: 1234,
      extraMs: 10000,
      totalActiveMs: 99999,
      trialCounted: true,
    );
    expect(EngineCheckpoint.fromJson(cp.toJson()).toJson(), cp.toJson());
  });
}
