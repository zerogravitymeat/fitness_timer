import 'package:flutter_test/flutter_test.dart';
import 'package:health_timer/engine/routine_compiler.dart';
import 'package:health_timer/engine/segment.dart';
import 'package:health_timer/models/presets.dart';
import 'package:health_timer/models/routine.dart';

String _types(List<Segment> s) => s
    .map(
      (e) => switch (e.type) {
        SegmentType.prep => 'P',
        SegmentType.work => 'W',
        SegmentType.rest => 'r',
        SegmentType.setRest => 'S',
      },
    )
    .join();

void main() {
  group('RoutineCompiler', () {
    test('타바타: 준비 + 운동 8 + 휴식 7 (마지막 라운드 휴식 건너뜀)', () {
      final s = RoutineCompiler.compile(Presets.tabata);
      expect(_types(s), 'P${'Wr' * 7}W');
      expect(
        RoutineCompiler.estimatedTotalMs(Presets.tabata),
        10000 + 8 * 20000 + 7 * 10000,
      );
    });

    test('마지막 라운드 휴식 건너뛰기 켜짐 + 2세트', () {
      const r = Routine(
        id: 'a',
        name: 'a',
        rounds: 3,
        sets: 2,
        skipLastRest: true,
      );
      expect(_types(RoutineCompiler.compile(r)), 'PWrWrWSWrWrW');
    });

    test('마지막 라운드 휴식 건너뛰기 꺼짐 + 2세트: 세트 끝 휴식 후 세트 간 휴식, 루틴 맨 끝 휴식은 뺀다', () {
      const r = Routine(
        id: 'a',
        name: 'a',
        rounds: 3,
        sets: 2,
        skipLastRest: false,
      );
      expect(_types(RoutineCompiler.compile(r)), 'PWrWrWrSWrWrW');
    });

    test('라운드·세트 번호', () {
      const r = Routine(id: 'a', name: 'a', rounds: 2, sets: 2);
      final works = RoutineCompiler.compile(r)
          .where((e) => e.type == SegmentType.work)
          .toList();
      expect(works.map((e) => '${e.set}-${e.round}'), [
        '1-1',
        '1-2',
        '2-1',
        '2-2',
      ]);
    });

    test('준비 0초, 휴식 0초, 세트 간 휴식 0초면 그 구간을 만들지 않는다', () {
      const r = Routine(
        id: 'a',
        name: 'a',
        prepMs: 0,
        restMs: 0,
        rounds: 2,
        sets: 2,
        setRestMs: 0,
      );
      expect(_types(RoutineCompiler.compile(r)), 'WWWW');
    });

    test('횟수 모드: 세트 수는 1로 고정, 운동 길이 = 횟수 × 1회 시간', () {
      const r = Routine(
        id: 'a',
        name: 'a',
        endCondition: EndCondition.reps,
        targetReps: 12,
        tempo: Tempo.normal,
        restMs: 90000,
        rounds: 3,
        sets: 3, // 무시되어야 함
      );
      final s = RoutineCompiler.compile(r);
      expect(_types(s), 'PWrWrW');
      expect(s[1].durationMs, 12 * 3000);
      expect(s[1].targetReps, 12);
      expect(s[1].isRepWork, isTrue);
    });

    test('근력 세트 프리셋 예상 시간', () {
      // 준비 10 + 운동 36 × 3 + 휴식 90 × 2
      expect(
        RoutineCompiler.estimatedTotalMs(Presets.strength),
        10000 + 36000 * 3 + 90000 * 2,
      );
    });
  });
}
