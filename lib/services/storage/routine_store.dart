import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../models/course.dart';
import '../../models/presets.dart';
import '../../models/routine.dart';
import '../../models/workout.dart';
import 'routine_repository.dart';

/// 화면이 쓰는 루틴 목록 상태. 바뀔 때마다 파일에 저장한다.
class RoutineStore extends ChangeNotifier {
  RoutineStore(this._repo, {int Function()? now})
    : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final RoutineRepository _repo;
  final int Function() _now;
  RoutineData _d = RoutineData();
  Future<void> _saving = Future.value();

  static final _rand = Random();

  Future<void> load() async {
    _d = await _repo.load();
    notifyListeners();
  }

  RoutineSort get sort => _d.sort;

  /// 정렬된 내 루틴
  List<Routine> get myRoutines =>
      _sorted(_d.routines, (r) => r.id, (r) => r.name, _d.sort, _d.customOrder);

  /// 내 루틴·코스 공통 정렬 (docs/02 8장)
  List<T> _sorted<T>(
    List<T> items,
    String Function(T) id,
    String Function(T) name,
    RoutineSort sort,
    List<String> customOrder,
  ) {
    final list = [...items];
    int created(T e) => _d.createdAt[id(e)] ?? 0;
    switch (sort) {
      case RoutineSort.recent:
        // 한 번도 안 쓴 항목은 만든 순서대로 뒤에
        list.sort((a, b) {
          final c = (_d.lastUsed[id(b)] ?? 0).compareTo(
            _d.lastUsed[id(a)] ?? 0,
          );
          return c != 0 ? c : created(b).compareTo(created(a));
        });
      case RoutineSort.name:
        list.sort((a, b) => name(a).compareTo(name(b)));
      case RoutineSort.created:
        list.sort((a, b) => created(b).compareTo(created(a)));
      case RoutineSort.custom:
        // 직접 정한 순서. 순서에 없는 항목(나중에 만든 것)은 맨 위에 최신순으로
        final pos = {for (final (i, x) in customOrder.indexed) x: i};
        list.sort((a, b) {
          final pa = pos[id(a)], pb = pos[id(b)];
          if (pa == null && pb == null) return created(b).compareTo(created(a));
          if (pa == null) return -1;
          if (pb == null) return 1;
          return pa.compareTo(pb);
        });
    }
    return list;
  }

  /// 화면 언어에 맞춘 프리셋. 이름만 바뀌고 저장하지 않는다.
  List<Routine> _presets = Presets.all;

  /// 프리셋 이름을 화면 언어로. 화면을 그리는 중에 부르므로 알리지 않는다.
  void setPresetNames(String Function(Routine preset) nameOf) {
    _presets = [for (final p in Presets.all) p.copyWith(name: nameOf(p))];
  }

  /// 프리셋 (사용자가 정한 순서, 없으면 기본 순서)
  List<Routine> get presets {
    final pos = {for (final (i, id) in _d.presetOrder.indexed) id: i};
    final list = [..._presets];
    final base = {for (final (i, r) in Presets.all.indexed) r.id: i};
    list.sort(
      (a, b) => (pos[a.id] ?? 1000 + base[a.id]!).compareTo(
        pos[b.id] ?? 1000 + base[b.id]!,
      ),
    );
    return list;
  }

  /// 프리셋 순서 바꾸기. [newIndex]는 옮긴 뒤 놓일 위치 (이미 보정된 값).
  Future<void> movePreset(int oldIndex, int newIndex) async {
    final ids = presets.map((r) => r.id).toList();
    ids.insert(newIndex, ids.removeAt(oldIndex));
    _d.presetOrder
      ..clear()
      ..addAll(ids);
    await _commit();
  }

  /// 내 루틴 순서 바꾸기. 정렬은 "직접 정렬"로 바뀐다.
  Future<void> moveMine(int oldIndex, int newIndex) async {
    final ids = myRoutines.map((r) => r.id).toList();
    ids.insert(newIndex, ids.removeAt(oldIndex));
    _d.customOrder
      ..clear()
      ..addAll(ids);
    _d.sort = RoutineSort.custom;
    await _commit();
  }

  List<Routine> get all => [..._presets, ..._d.routines];

  Routine? byId(String id) => all.where((r) => r.id == id).firstOrNull;

  /// 즐겨찾기 (프리셋 + 내 루틴), 최근 사용순
  List<Routine> get favorites {
    final list = all.where((r) => _d.favorites.contains(r.id)).toList();
    list.sort(
      (a, b) => (_d.lastUsed[b.id] ?? 0).compareTo(_d.lastUsed[a.id] ?? 0),
    );
    return list;
  }

  /// 마지막으로 시작한 루틴 (지워진 루틴은 제외)
  Routine? get recent {
    Routine? best;
    var bestAt = 0;
    for (final r in all) {
      final at = _d.lastUsed[r.id] ?? 0;
      if (at > bestAt) {
        best = r;
        bestAt = at;
      }
    }
    return best;
  }

  bool isFavorite(String id) => _d.favorites.contains(id);

  /// 새 루틴의 id
  String newId() =>
      'r${_now().toRadixString(36)}${_rand.nextInt(1 << 30).toRadixString(36)}';

  /// 새로 만들기 또는 수정. 프리셋은 저장하지 않는다.
  Future<void> save(Routine r) async {
    assert(!r.isPreset, '프리셋은 저장할 수 없다');
    if (r.isPreset) return;
    final i = _d.routines.indexWhere((e) => e.id == r.id);
    if (i >= 0) {
      _d.routines[i] = r;
    } else {
      _d.routines.add(r);
      _d.createdAt[r.id] = _now();
    }
    await _commit();
  }

  /// 루틴을 지우면 그 루틴이 들어간 코스에서도 빠진다 (docs/02 8-1장)
  Future<void> delete(String id) async {
    _d.routines.removeWhere((r) => r.id == id);
    for (final (i, c) in _d.courses.indexed.toList()) {
      if (c.steps.any((s) => s.routineId == id)) {
        _d.courses[i] = c.copyWith(
          steps: [
            for (final s in c.steps)
              if (s.routineId != id) s,
          ],
        );
      }
    }
    _d.customOrder.remove(id);
    _d.createdAt.remove(id);
    _d.favorites.remove(id);
    _d.lastUsed.remove(id);
    await _commit();
  }

  Future<void> toggleFavorite(String id) async {
    if (!_d.favorites.remove(id)) _d.favorites.add(id);
    await _commit();
  }

  Future<void> markUsed(String id) async {
    _d.lastUsed[id] = _now();
    await _commit();
  }

  Future<void> setSort(RoutineSort s) async {
    _d.sort = s;
    await _commit();
  }

  /// "복사해서 수정"용 사본. 아직 저장하지 않는다.
  /// [format]은 언어별 사본 이름 (예: "{name} 복사").
  Routine copyOf(Routine r, String Function(String name) format) =>
      r.copyWith(id: newId(), isPreset: false, name: copyName(r.name, format));

  /// 사본 이름. 이름 길이 제한을 넘지 않도록 원래 이름을 자른다.
  static String copyName(String name, String Function(String name) format) {
    final room = RoutineLimits.maxNameLength - format('').length;
    return format(name.length > room ? name.substring(0, room) : name);
  }

  // ── 코스 (docs/02 8-1장) ─────────────────────────

  RoutineSort get courseSort => _d.courseSort;

  /// 정렬된 코스 (내 루틴과 같은 4가지 정렬, 따로 선택)
  List<Course> get courses => _sorted(
    _d.courses,
    (c) => c.id,
    (c) => c.name,
    _d.courseSort,
    _d.courseOrder,
  );

  Future<void> setCourseSort(RoutineSort s) async {
    _d.courseSort = s;
    await _commit();
  }

  Course? courseById(String id) =>
      _d.courses.where((c) => c.id == id).firstOrNull;

  String newCourseId() =>
      'c${_now().toRadixString(36)}${_rand.nextInt(1 << 30).toRadixString(36)}';

  /// 코스를 실제로 진행할 내용으로 (지워진 루틴은 빠진다)
  Workout workoutOf(Course c) => Workout.course(c, byId);

  /// 이 루틴이 들어간 코스 수 (루틴 삭제 확인 창용)
  int coursesUsing(String routineId) => _d.courses
      .where((c) => c.steps.any((s) => s.routineId == routineId))
      .length;

  Future<void> saveCourse(Course c) async {
    c = c.normalized();
    final i = _d.courses.indexWhere((e) => e.id == c.id);
    if (i >= 0) {
      _d.courses[i] = c;
    } else {
      _d.courses.add(c);
      _d.createdAt[c.id] = _now();
    }
    await _commit();
  }

  Future<void> deleteCourse(String id) async {
    _d.courses.removeWhere((c) => c.id == id);
    _d.courseOrder.remove(id);
    _d.createdAt.remove(id);
    _d.lastUsed.remove(id);
    await _commit();
  }

  Future<void> moveCourse(int oldIndex, int newIndex) async {
    final ids = courses.map((c) => c.id).toList();
    ids.insert(newIndex, ids.removeAt(oldIndex));
    _d.courseOrder
      ..clear()
      ..addAll(ids);
    _d.courseSort = RoutineSort.custom;
    await _commit();
  }

  /// 화면에는 바로 반영하고, 파일 쓰기는 순서대로 한다.
  Future<void> _commit() {
    notifyListeners();
    return _saving = _saving.then((_) => _repo.save(_d)).catchError((Object e) {
      debugPrint('RoutineStore: 저장 실패 $e');
    });
  }
}
