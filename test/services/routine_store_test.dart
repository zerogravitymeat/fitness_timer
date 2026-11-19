import 'dart:io';

import 'package:fitness_timer/models/presets.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:fitness_timer/services/storage/routine_repository.dart';
import 'package:fitness_timer/services/storage/routine_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late int now;
  RoutineStore newStore() =>
      RoutineStore(RoutineRepository(dir), now: () => now);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('routines_test');
    now = 1000;
  });
  tearDown(() => dir.delete(recursive: true));

  Routine r(String id, String name) => Routine(id: id, name: name, rounds: 3);

  test('저장한 루틴·즐겨찾기·최근 사용·정렬이 다시 불러와도 유지된다', () async {
    final a = newStore();
    await a.load();
    await a.save(r('a', '하체'));
    now = 2000;
    await a.save(r('b', '상체'));
    await a.toggleFavorite('b');
    await a.toggleFavorite(Presets.tabata.id);
    now = 3000;
    await a.markUsed('a');
    await a.setSort(RoutineSort.name);

    final b = newStore();
    await b.load();
    expect(b.myRoutines.map((e) => e.name), ['상체', '하체']); // 이름순
    expect(b.favorites.map((e) => e.id), containsAll(['b', Presets.tabata.id]));
    expect(b.recent!.id, 'a');
    expect(b.sort, RoutineSort.name);
    expect(b.byId('a')!.rounds, 3);
  });

  test('정렬: 최근 사용순(안 쓴 건 만든 순으로 뒤에), 만든 순', () async {
    final s = newStore();
    await s.load();
    now = 1;
    await s.save(r('old', '가'));
    now = 2;
    await s.save(r('mid', '나'));
    now = 3;
    await s.save(r('new', '다'));
    now = 10;
    await s.markUsed('old');

    expect(s.myRoutines.map((e) => e.id), ['old', 'new', 'mid']);
    await s.setSort(RoutineSort.created);
    expect(s.myRoutines.map((e) => e.id), ['new', 'mid', 'old']);
  });

  test('수정하면 같은 자리에 덮어쓰고 만든 시각은 유지', () async {
    final s = newStore();
    await s.load();
    await s.save(r('a', '하체'));
    now = 5000;
    await s.save(r('a', '하체 강화').copyWith(rounds: 5));
    expect(s.myRoutines.single.name, '하체 강화');
    expect(s.myRoutines.single.rounds, 5);

    final again = newStore();
    await again.load();
    await again.setSort(RoutineSort.created);
    expect(again.myRoutines.single.rounds, 5);
  });

  test('삭제하면 즐겨찾기와 최근 사용 기록도 함께 지운다', () async {
    final s = newStore();
    await s.load();
    await s.save(r('a', '하체'));
    await s.toggleFavorite('a');
    await s.markUsed('a');
    await s.delete('a');
    expect(s.myRoutines, isEmpty);
    expect(s.favorites, isEmpty);
    expect(s.recent, isNull);
  });

  test('복사해서 수정: 새 id, 프리셋 아님, 이름에 "복사"', () async {
    final s = newStore();
    await s.load();
    final c = s.copyOf(Presets.tabata);
    expect(c.id, isNot(Presets.tabata.id));
    expect(c.isPreset, isFalse);
    expect(c.name, '타바타 복사');
    expect(c.workMs, Presets.tabata.workMs);

    final long = s.copyOf(Routine(id: 'x', name: '가' * 20));
    expect(long.name.length, lessThanOrEqualTo(RoutineLimits.maxNameLength));
  });

  test('파일이 깨져 있으면 사본을 남기고 빈 목록으로 시작', () async {
    await File('${dir.path}/routines.json').writeAsString('{not json');
    final s = newStore();
    await s.load();
    expect(s.myRoutines, isEmpty);
    final broken = dir.listSync().where((f) => f.path.contains('.broken.'));
    expect(broken, hasLength(1));
  });

  test('프리셋으로 표시된 항목이 파일에 있어도 내 루틴으로 읽지 않는다', () async {
    final repo = RoutineRepository(dir);
    await repo.save(RoutineData(routines: [Presets.tabata, r('a', '하체')]));
    final s = newStore();
    await s.load();
    expect(s.myRoutines.map((e) => e.id), ['a']);
  });

  test('저장 파일에 schemaVersion이 들어간다', () async {
    final s = newStore();
    await s.load();
    await s.save(r('a', '하체'));
    final text = await File('${dir.path}/routines.json').readAsString();
    expect(text, contains('"schemaVersion":1'));
  });
}
