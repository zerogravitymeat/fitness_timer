import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_timer/engine/routine_compiler.dart';
import 'package:fitness_timer/engine/segment.dart';
import 'package:fitness_timer/models/course.dart';
import 'package:fitness_timer/models/presets.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:fitness_timer/models/workout.dart';

String _types(List<Segment> s) => s
    .map(
      (e) => switch (e.type) {
        SegmentType.prep => 'P',
        SegmentType.work => 'W',
        SegmentType.rest => 'r',
        SegmentType.setRest => 'S',
        SegmentType.courseRest => 'C',
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
      // 준비 10 + 운동 45(15회 × 3초) × 3 + 휴식 90 × 2
      expect(
        RoutineCompiler.estimatedTotalMs(Presets.strength),
        10000 + 45000 * 3 + 90000 * 2,
      );
    });
  });

  group('코스 (docs/02 8-1장)', () {
    const plankShort = Routine(
      id: 'p',
      name: '플랭크',
      prepMs: 5000,
      workMs: 30000,
      restMs: 10000,
      rounds: 2,
    );

    test('준비는 첫 루틴 것만, 루틴 사이에 휴식, 각 루틴 끝의 휴식은 빠짐', () {
      final w = Workout(
        name: '코스',
        routines: [Presets.tabata, plankShort],
        restsMs: [60000],
        courseId: 'c',
      );
      final segs = RoutineCompiler.compileWorkout(w);
      expect(
        _types(segs),
        'P${'Wr' * 7}W'
        'C'
        'WrW',
      );
      final c = segs.firstWhere((s) => s.type == SegmentType.courseRest);
      expect(c.durationMs, 60000);
      expect(c.part, 1); // 루틴 사이 휴식은 다음 루틴 번호
      expect(segs.last.part, 1);
      expect(segs.first.part, 0);
      expect(
        RoutineCompiler.estimatedWorkoutMs(w),
        RoutineCompiler.estimatedTotalMs(Presets.tabata) +
            60000 +
            (30000 * 2 + 10000),
      );
    });

    test('휴식 0이면 바로 다음 루틴 운동', () {
      final w = Workout(
        name: '코스',
        routines: [plankShort, plankShort],
        restsMs: [0],
        courseId: 'c',
      );
      expect(
        _types(RoutineCompiler.compileWorkout(w)),
        'PWrW'
        'WrW',
      );
    });

    test('루틴 하나는 기존 컴파일과 같다', () {
      expect(
        _types(RoutineCompiler.compileWorkout(Workout.single(Presets.hiit))),
        _types(RoutineCompiler.compile(Presets.hiit)),
      );
    });

    test('지워진 루틴은 건너뛰고 휴식도 함께 빠진다', () {
      final w = Workout.course(
        const Course(
          id: 'c',
          name: '코스',
          steps: [
            CourseStep(routineId: 'a', restAfterMs: 10000),
            CourseStep(routineId: 'gone', restAfterMs: 20000),
            CourseStep(routineId: 'b', restAfterMs: 30000),
          ],
        ),
        (id) => id == 'gone' ? null : plankShort.copyWith(id: id),
      );
      expect(w.routines.map((r) => r.id), ['a', 'b']);
      expect(w.restsMs, [10000]);
    });
  });
}
