import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_timer/engine/segment.dart';
import 'package:fitness_timer/engine/tempo_clock.dart';
import 'package:fitness_timer/engine/timer_core.dart';
import 'package:fitness_timer/models/presets.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:fitness_timer/services/run/run_labels.dart';
import 'package:fitness_timer/services/run/run_view.dart';

void main() {
  test('Routine JSON 왕복', () {
    for (final r in Presets.all) {
      final back = Routine.fromJson(r.toJson());
      expect(back.toJson(), r.toJson(), reason: r.name);
    }
  });

  test('Routine.fromJson: 빠지거나 이상한 값은 기본값', () {
    final r = Routine.fromJson({
      'id': 'x',
      'endCondition': 'banana',
      'rounds': 3.0,
    });
    expect(r.endCondition, EndCondition.time);
    expect(r.rounds, 3);
    expect(r.tempo, Tempo.normal);
  });

  test('RunView: 서비스 → 화면 Map 왕복', () {
    var now = 0;
    final core = TimerCore(routine: Presets.strength, clock: () => now);
    core.start();
    now = 10000 + 7500;
    core.tick();
    final v = RunView.from(core);
    final back = RunView.fromMap(v.toMap());
    expect(back.toMap(), v.toMap());
    expect(back.segmentType, SegmentType.work);
    expect(back.completedReps, 2);
    expect(back.tempoPhase, TempoPhase.down);
    expect(back.nextType, SegmentType.rest);
  });

  test('RunView.advancedBy: 화면 보간이 구간 끝을 넘지 않는다', () {
    var now = 0;
    final core = TimerCore(routine: Presets.tabata, clock: () => now);
    core.start();
    now = 15000;
    core.tick();
    final v = RunView.from(core);
    expect(v.advancedBy(2000).segmentRemainingMs, 13000);
    expect(v.advancedBy(99999).segmentRemainingMs, 0);
    core.pause();
    expect(RunView.from(core).advancedBy(5000).segmentElapsedMs, 5000);
  });

  test('표시 문구', () {
    expect(RunLabels.clock(16200), '0:17');
    expect(RunLabels.clock(0), '0:00');
    expect(RunLabels.clock(90000), '1:30');
    expect(RunLabels.segment(SegmentType.rest, isReps: true), '세트 간 휴식');
    expect(RunLabels.segment(SegmentType.rest, isReps: false), '휴식');

    var now = 0;
    final core = TimerCore(routine: Presets.tabata, clock: () => now);
    core.start();
    now = 15000;
    core.tick();
    final v = RunView.from(core);
    expect(RunLabels.progress(v), '라운드 1/8');
    expect(RunLabels.next(v), '다음: 휴식 10초');
  });
}
