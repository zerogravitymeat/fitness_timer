import 'dart:convert';
import 'dart:io';

import 'package:fitness_timer/engine/segment.dart';
import 'package:fitness_timer/engine/timer_core.dart';
import 'package:fitness_timer/models/course.dart';
import 'package:fitness_timer/models/entitlement.dart';
import 'package:fitness_timer/models/presets.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:fitness_timer/models/workout.dart';
import 'package:fitness_timer/services/run/run_labels.dart';
import 'package:fitness_timer/services/run/run_view.dart';
import 'package:fitness_timer/services/storage/routine_repository.dart';
import 'package:fitness_timer/services/storage/routine_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// 코스 진행 (docs/02 8-1장)
void main() {
  const plank = Routine(
    id: 'p',
    name: '플랭크',
    prepMs: 5000,
    workMs: 30000,
    restMs: 10000,
    rounds: 2,
  );
  const squat = Routine(
    id: 's',
    name: '스쿼트',
    endCondition: EndCondition.reps,
    prepMs: 10000,
    targetReps: 5,
    tempo: Tempo.normal, // 1회 3초
    restMs: 20000,
    rounds: 2,
  );
  // 플랭크: 준비5 + 운동30 + 휴식10 + 운동30 = 75초
  // 휴식 40초
  // 스쿼트: 운동15 + 휴식20 + 운동15 = 50초 (준비 없음)
  const course = Workout(
    name: '아침 코스',
    routines: [plank, squat],
    restsMs: [40000],
    courseId: 'c',
  );

  late int now;
  setUp(() => now = 0);

  List<EngineEvent> runTo(TimerCore core, int until) {
    final events = <EngineEvent>[];
    while (now < until) {
      now += 10;
      events.addAll(core.tick());
    }
    return events;
  }

  Iterable<String> speeches(List<EngineEvent> e) =>
      e.whereType<CueDue>().map((c) => c.cue.speech).whereType<String>();

  test('끝까지 진행: 루틴 이름과 루틴 사이 휴식을 알리고 한 번에 끝난다', () {
    final core = TimerCore.workout(workout: course, clock: () => now);
    final events = [...core.start(), ...runTo(core, 165000 + 100)];
    final said = speeches(events).toList();
    expect(said, contains('플랭크, 1라운드, 운동 시작'));
    expect(said, contains('휴식 40초, 다음은 스쿼트'));
    expect(said, contains('스쿼트, 1세트, 5회 시작'));
    final f = events.whereType<Finished>().single;
    expect(f.totalActiveMs, 165000);
    expect(f.stopped, isFalse);
    // 무료 운동은 코스 하나에 1회만
    expect(events.whereType<TrialCountable>().length, 1);
  });

  test('루틴 사이 휴식: 화면 문구, +10초, 다음 루틴 템포', () {
    final core = TimerCore.workout(workout: course, clock: () => now);
    core.start();
    runTo(core, 60000); // 플랭크 마지막 운동 중
    var v = RunView.from(core);
    expect(v.isCourse, isTrue);
    expect(RunLabels.coursePosition(v), '1/2 플랭크');
    expect(RunLabels.next(v), '다음: 휴식 40초');

    runTo(core, 80000); // 루틴 사이 휴식
    v = RunView.from(core);
    expect(v.segmentType, SegmentType.courseRest);
    expect(RunLabels.segment(v.segmentType, isReps: v.isReps), '휴식');
    expect(RunLabels.progress(v), '루틴 1/2 완료');
    expect(RunLabels.next(v), '다음: 스쿼트');
    expect(v.routineName, '스쿼트');

    core.addRest(10000);
    expect(RunView.from(core).segmentDurationMs, 50000);

    runTo(core, 75000 + 50000 + 4000); // 스쿼트 첫 운동 4초째
    v = RunView.from(core);
    expect(v.segmentType, SegmentType.work);
    expect(v.routineName, '스쿼트');
    expect(v.targetReps, 5);
    expect(v.completedReps, 1); // 1회 3초 (보통 템포)
    expect(RunLabels.progress(v), '세트 1/2');
  });

  test('다음/이전으로 루틴 경계를 넘나든다', () {
    final core = TimerCore.workout(workout: course, clock: () => now);
    core.start();
    // 준비 → 운동 → 휴식 → 운동 → 루틴 사이 휴식
    for (var i = 0; i < 4; i++) {
      core.next();
    }
    expect(core.snapshot().segment!.type, SegmentType.courseRest);
    core.next();
    expect(core.snapshot().segment!.part, 1);
    core.prev();
    expect(core.snapshot().segment!.type, SegmentType.courseRest);
  });

  test('이어하기: 두 번째 루틴 위치에서 다시 시작', () {
    final a = TimerCore.workout(workout: course, clock: () => now);
    a.start();
    runTo(a, 125000); // 스쿼트 첫 운동 중
    final cp = a.checkpoint;
    expect(a.snapshot().segment!.part, 1);

    now = 0;
    final b = TimerCore.workout(
      workout: Workout.fromJson(course.toJson()),
      clock: () => now,
    );
    b.restore(cp);
    final s = b.snapshot();
    expect(s.segmentIndex, cp.segmentIndex);
    expect(s.segment!.part, 1);
    expect(s.totalActiveMs, 125000);
  });

  test('체험 종료 후: 프리셋만 넣은 코스도 잠긴다', () {
    const ended = Entitlement(isFull: false, freeUsed: 15);
    final presetsOnly = Workout.course(
      Course(
        id: 'c',
        name: '프리셋 코스',
        steps: [CourseStep(routineId: Presets.tabata.id)],
      ),
      (id) => Presets.all.where((r) => r.id == id).firstOrNull,
    );
    expect(ended.canStartWorkout(presetsOnly), isFalse);
    expect(ended.canStartWorkout(Workout.single(Presets.tabata)), isTrue);
    expect(ended.canStartWorkout(Workout.single(plank)), isFalse);
  });

  test('저장 값이 손상돼 휴식이 범위를 넘어도 30분으로 자른다', () {
    final w = Workout.fromJson({
      ...course.toJson(),
      'restsMs': [999999999],
    });
    final core = TimerCore.workout(workout: w, clock: () => now);
    final rest = core.segments.firstWhere(
      (s) => s.type == SegmentType.courseRest,
    );
    expect(rest.durationMs, CourseLimits.maxRestMs);
  });

  group('RoutineStore 코스', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('course'));
    tearDown(() => dir.delete(recursive: true));

    test('저장·순서·삭제가 다시 불러와도 유지되고, 루틴을 지우면 코스에서 빠진다', () async {
      var t = 1000;
      final a = RoutineStore(RoutineRepository(dir), now: () => t);
      await a.load();
      await a.save(plank);
      await a.saveCourse(
        const Course(
          id: 'c1',
          name: '첫 코스',
          steps: [
            CourseStep(routineId: 'p', restAfterMs: 0),
            CourseStep(routineId: 'preset_tabata'),
          ],
        ),
      );
      t = 2000;
      await a.saveCourse(const Course(id: 'c2', name: '둘째 코스'));
      expect(a.courses.map((c) => c.id), ['c2', 'c1']); // 새 코스가 위
      await a.moveCourse(0, 1);
      expect(a.coursesUsing('p'), 1);

      final b = RoutineStore(RoutineRepository(dir), now: () => t);
      await b.load();
      expect(b.courses.map((c) => c.id), ['c1', 'c2']);
      expect(b.courseSort, RoutineSort.custom); // 옮기면 직접 정렬
      expect(b.sort, RoutineSort.recent); // 내 루틴 정렬과는 따로
      await b.setCourseSort(RoutineSort.name);
      expect(b.courses.map((c) => c.name), ['둘째 코스', '첫 코스']);
      t = 3000;
      await b.markUsed('c2');
      await b.setCourseSort(RoutineSort.recent);
      expect(b.courses.map((c) => c.id), ['c2', 'c1']);
      final c1 = b.courseById('c1')!;
      expect(c1.steps.first.restAfterMs, 0);
      expect(b.workoutOf(c1).routines.map((r) => r.name), ['플랭크', '타바타']);

      await b.delete('p');
      expect(b.courseById('c1')!.steps.map((s) => s.routineId), [
        'preset_tabata',
      ]);
      await b.deleteCourse('c2');

      final c = RoutineStore(RoutineRepository(dir), now: () => t);
      await c.load();
      expect(c.courses.map((e) => e.id), ['c1']);
      expect(c.courseById('c1')!.steps.length, 1);
    });

    test('코스 정렬 전 파일: 옮겨 둔 순서가 있으면 직접 정렬로 시작', () async {
      await File('${dir.path}/${RoutineRepository.fileName}').writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'courses': [
            {'id': 'a', 'name': '가', 'createdAt': 1},
            {'id': 'b', 'name': '나', 'createdAt': 2},
          ],
          'courseOrder': ['a', 'b'],
        }),
      );
      final s = RoutineStore(RoutineRepository(dir));
      await s.load();
      expect(s.courseSort, RoutineSort.custom);
      expect(s.courses.map((c) => c.id), ['a', 'b']);
    });
  });
}
