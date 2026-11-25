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
    now = 3000;
    await a.markUsed('a');
    await a.setSort(RoutineSort.name);

    final b = newStore();
    await b.load();
    expect(b.myRoutines.map((e) => e.name), ['상체', '하체']); // 이름순
    expect(b.isFavorite('b'), isTrue);
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
    expect(s.isFavorite('a'), isFalse);
    expect(s.recent, isNull);
  });

  test('복사해서 수정: 새 id, 프리셋 아님, 이름에 "복사"', () async {
    final s = newStore();
    await s.load();
    final c = s.copyOf(Presets.tabata, (n) => '$n 복사');
    expect(c.id, isNot(Presets.tabata.id));
    expect(c.isPreset, isFalse);
    expect(c.name, '타바타 복사');
    expect(c.workMs, Presets.tabata.workMs);

    final long = s.copyOf(Routine(id: 'x', name: '가' * 20), (n) => '$n 복사');
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

  test('프리셋은 항상 기본 순서이고 즐겨찾기할 수 없다', () async {
    final s = newStore();
    await s.load();
    expect(s.presets.map((e) => e.id), Presets.all.map((e) => e.id));
    await s.toggleFavorite(Presets.tabata.id);
    expect(s.isFavorite(Presets.tabata.id), isFalse);
  });

  test('예전 파일의 프리셋 즐겨찾기·프리셋 순서는 무시한다', () async {
    await File('${dir.path}/routines.json').writeAsString(
      '{"schemaVersion":1,"routines":[],"favorites":["${Presets.hiit.id}"],'
      '"presetOrder":["${Presets.strength.id}"]}',
    );
    final s = newStore();
    await s.load();
    expect(s.isFavorite(Presets.hiit.id), isFalse);
    expect(s.presets.first.id, Presets.tabata.id);
  });

  test('즐겨찾기한 루틴은 정렬과 상관없이 맨 위', () async {
    final s = newStore();
    await s.load();
    await s.save(r('a', '가'));
    await s.save(r('b', '나'));
    await s.save(r('c', '다'));
    await s.setSort(RoutineSort.name);
    await s.toggleFavorite('c');
    expect(s.myRoutines.map((e) => e.id), ['c', 'a', 'b']);
    expect(s.favoriteCount, 1);
    await s.toggleFavorite('c');
    expect(s.myRoutines.map((e) => e.id), ['a', 'b', 'c']);
  });

  test('순서 바꾸기는 즐겨찾기끼리, 나머지끼리만', () async {
    final s = newStore();
    await s.load();
    await s.save(r('a', '가'));
    await s.save(r('b', '나'));
    await s.save(r('c', '다'));
    await s.setSort(RoutineSort.name);
    await s.toggleFavorite('c'); // c | a b
    await s.moveMine(2, 0); // b를 즐겨찾기 위로 → 나머지 맨 위에서 멈춤
    expect(s.myRoutines.map((e) => e.id), ['c', 'b', 'a']);
    await s.moveMine(0, 2); // c를 아래로 → 즐겨찾기 자리 그대로
    expect(s.myRoutines.map((e) => e.id), ['c', 'b', 'a']);
  });

  test('홈에서 마지막으로 본 탭을 기억한다', () async {
    final a = newStore();
    await a.load();
    expect(a.homeTab, HomeTab.routines);
    await a.setHomeTab(HomeTab.courses);
    final b = newStore();
    await b.load();
    expect(b.homeTab, HomeTab.courses);
  });

  test('내 루틴 순서 바꾸기: 직접 정렬로 바뀌고 유지, 새 루틴은 맨 위', () async {
    final s = newStore();
    await s.load();
    now = 1;
    await s.save(r('a', '가'));
    now = 2;
    await s.save(r('b', '나'));
    now = 3;
    await s.save(r('c', '다'));
    await s.setSort(RoutineSort.name); // 가 나 다
    await s.moveMine(0, 2); // 가를 맨 아래로 → 나 다 가
    expect(s.sort, RoutineSort.custom);
    expect(s.myRoutines.map((e) => e.id), ['b', 'c', 'a']);

    final again = newStore();
    await again.load();
    expect(again.myRoutines.map((e) => e.id), ['b', 'c', 'a']);

    now = 9;
    await again.save(r('d', '라')); // 순서에 없는 새 루틴
    expect(again.myRoutines.map((e) => e.id), ['d', 'b', 'c', 'a']);

    await again.delete('c');
    expect(again.myRoutines.map((e) => e.id), ['d', 'b', 'a']);
  });
}
