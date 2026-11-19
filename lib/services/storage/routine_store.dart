import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../models/presets.dart';
import '../../models/routine.dart';
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
  List<Routine> get myRoutines {
    final list = [..._d.routines];
    switch (_d.sort) {
      case RoutineSort.recent:
        // 한 번도 안 쓴 루틴은 만든 순서대로 뒤에
        list.sort((a, b) {
          final c = (_d.lastUsed[b.id] ?? 0).compareTo(_d.lastUsed[a.id] ?? 0);
          return c != 0 ? c : _created(b).compareTo(_created(a));
        });
      case RoutineSort.name:
        list.sort((a, b) => a.name.compareTo(b.name));
      case RoutineSort.created:
        list.sort((a, b) => _created(b).compareTo(_created(a)));
    }
    return list;
  }

  int _created(Routine r) => _d.createdAt[r.id] ?? 0;

  List<Routine> get all => [...Presets.all, ..._d.routines];

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

  Future<void> delete(String id) async {
    _d.routines.removeWhere((r) => r.id == id);
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
  Routine copyOf(Routine r) {
    final base = r.name.length > RoutineLimits.maxNameLength - 3
        ? r.name.substring(0, RoutineLimits.maxNameLength - 3)
        : r.name;
    return r.copyWith(id: newId(), isPreset: false, name: '$base 복사');
  }

  /// 화면에는 바로 반영하고, 파일 쓰기는 순서대로 한다.
  Future<void> _commit() {
    notifyListeners();
    return _saving = _saving.then((_) => _repo.save(_d)).catchError((Object e) {
      debugPrint('RoutineStore: 저장 실패 $e');
    });
  }
}
