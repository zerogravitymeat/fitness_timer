import 'dart:convert';
import 'dart:io';

import '../../models/routine.dart';

/// 내 루틴 목록 정렬 (docs/02_기능_명세.md 8장)
enum RoutineSort { recent, name, created }

/// 파일에 저장되는 내용 전체
class RoutineData {
  RoutineData({
    List<Routine>? routines,
    Map<String, int>? createdAt,
    Set<String>? favorites,
    Map<String, int>? lastUsed,
    this.sort = RoutineSort.recent,
  }) : routines = routines ?? [],
       createdAt = createdAt ?? {},
       favorites = favorites ?? {},
       lastUsed = lastUsed ?? {};

  /// 내 루틴 (프리셋은 코드에 있으므로 저장하지 않는다)
  final List<Routine> routines;

  /// 루틴 id → 만든 시각 (epoch ms)
  final Map<String, int> createdAt;

  /// 즐겨찾기한 id. 프리셋 id도 들어갈 수 있다.
  final Set<String> favorites;

  /// 루틴 id → 마지막으로 시작한 시각 (epoch ms). 프리셋 id도 들어갈 수 있다.
  final Map<String, int> lastUsed;

  RoutineSort sort;
}

/// 내 루틴을 JSON 파일 하나에 저장한다 (docs/05_기술_설계.md 5.1절).
///
/// - 저장할 때는 임시 파일에 쓴 뒤 이름을 바꿔서, 쓰는 도중 앱이 꺼져도
///   기존 파일이 깨지지 않게 한다.
/// - 파일이 깨져 있으면 `.broken` 사본을 남기고 빈 목록으로 시작한다.
class RoutineRepository {
  RoutineRepository(this.directory);

  static const schemaVersion = 1;
  static const fileName = 'routines.json';

  final Directory directory;

  File get _file => File('${directory.path}/$fileName');

  Future<RoutineData> load() async {
    final f = _file;
    if (!await f.exists()) return RoutineData();
    try {
      final j = jsonDecode(await f.readAsString());
      return _decode((j as Map).cast<String, Object?>());
    } catch (_) {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await f.copy('${f.path}.broken.$stamp');
      return RoutineData();
    }
  }

  Future<void> save(RoutineData d) async {
    await directory.create(recursive: true);
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode(_encode(d)), flush: true);
    await tmp.rename(_file.path);
  }

  static Map<String, Object?> _encode(RoutineData d) => {
    'schemaVersion': schemaVersion,
    'routines': [
      for (final r in d.routines)
        {...r.toJson(), 'createdAt': d.createdAt[r.id] ?? 0},
    ],
    'favorites': d.favorites.toList()..sort(),
    'lastUsed': d.lastUsed,
    'sort': d.sort.name,
  };

  static RoutineData _decode(Map<String, Object?> j) {
    final routines = <Routine>[];
    final createdAt = <String, int>{};
    for (final item in (j['routines'] as List? ?? const [])) {
      if (item is! Map) continue;
      final m = item.cast<String, Object?>();
      final r = Routine.fromJson(m);
      if (r.id.isEmpty || r.isPreset) continue;
      routines.add(r);
      createdAt[r.id] = (m['createdAt'] as num?)?.toInt() ?? 0;
    }
    final lastUsed = <String, int>{};
    final lu = j['lastUsed'];
    if (lu is Map) {
      lu.forEach((k, v) {
        if (k is String && v is num) lastUsed[k] = v.toInt();
      });
    }
    return RoutineData(
      routines: routines,
      createdAt: createdAt,
      favorites: {
        for (final f in (j['favorites'] as List? ?? const []))
          if (f is String) f,
      },
      lastUsed: lastUsed,
      sort:
          RoutineSort.values.where((e) => e.name == j['sort']).firstOrNull ??
          RoutineSort.recent,
    );
  }
}
