import 'dart:convert';
import 'dart:io';

import '../../models/course.dart';
import '../../models/routine.dart';

/// 내 루틴 목록 정렬 (docs/02_기능_명세.md 8장)
enum RoutineSort {
  recent,
  name,
  created,

  /// 사용자가 끌어서 정한 순서
  custom,
}

/// 홈 "내 운동"에서 보고 있는 탭 (docs/03 3장). 마지막으로 본 탭을 기억한다.
enum HomeTab { routines, courses }

/// 파일에 저장되는 내용 전체
class RoutineData {
  RoutineData({
    List<Routine>? routines,
    Map<String, int>? createdAt,
    Set<String>? favorites,
    Map<String, int>? lastUsed,
    List<String>? customOrder,
    List<Course>? courses,
    List<String>? courseOrder,
    this.sort = RoutineSort.recent,
    this.courseSort = RoutineSort.recent,
    this.homeTab = HomeTab.routines,
  }) : routines = routines ?? [],
       courses = courses ?? [],
       courseOrder = courseOrder ?? [],
       customOrder = customOrder ?? [],
       createdAt = createdAt ?? {},
       favorites = favorites ?? {},
       lastUsed = lastUsed ?? {};

  /// 내 루틴 (프리셋은 코드에 있으므로 저장하지 않는다)
  final List<Routine> routines;

  /// 루틴 id → 만든 시각 (epoch ms)
  final Map<String, int> createdAt;

  /// 즐겨찾기한 내 루틴 id. 프리셋은 즐겨찾기하지 않는다 (2026-11-25).
  final Set<String> favorites;

  /// 루틴 id → 마지막으로 시작한 시각 (epoch ms). 프리셋 id도 들어갈 수 있다.
  final Map<String, int> lastUsed;

  /// 내 루틴을 직접 정렬했을 때의 순서 (루틴 id)
  final List<String> customOrder;

  /// 코스 (docs/02 8-1장). 만든 시각은 [createdAt]에 함께 둔다.
  final List<Course> courses;

  /// 코스 표시 순서 (코스 id). 순서에 없는 코스는 맨 위에 최신순.
  final List<String> courseOrder;

  RoutineSort sort;

  /// 코스 목록 정렬 (내 루틴 정렬과 따로)
  RoutineSort courseSort;

  HomeTab homeTab;
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
    'customOrder': d.customOrder,
    'courses': [
      for (final c in d.courses)
        {...c.toJson(), 'createdAt': d.createdAt[c.id] ?? 0},
    ],
    'courseOrder': d.courseOrder,
    'sort': d.sort.name,
    'courseSort': d.courseSort.name,
    'homeTab': d.homeTab.name,
  };

  static RoutineSort _sort(Object? v) =>
      RoutineSort.values.where((e) => e.name == v).firstOrNull ??
      RoutineSort.recent;

  static List<String> _strings(Object? v) => [
    for (final e in (v is List ? v : const []))
      if (e is String) e,
  ];

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
    final courses = <Course>[];
    for (final item in (j['courses'] as List? ?? const [])) {
      if (item is! Map) continue;
      final m = item.cast<String, Object?>();
      final c = Course.fromJson(m);
      if (c.id.isEmpty) continue;
      courses.add(c);
      createdAt[c.id] = (m['createdAt'] as num?)?.toInt() ?? 0;
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
      customOrder: _strings(j['customOrder']),
      courses: courses,
      courseOrder: _strings(j['courseOrder']),
      sort: _sort(j['sort']),
      // 코스 정렬이 생기기 전에는 코스가 항상 직접 정한 순서였다.
      // 그때 옮겨 둔 순서가 있으면 그대로 보이게 "직접 정렬"로 시작한다.
      courseSort: j.containsKey('courseSort')
          ? _sort(j['courseSort'])
          : _strings(j['courseOrder']).isNotEmpty
          ? RoutineSort.custom
          : RoutineSort.recent,
      homeTab:
          HomeTab.values.where((e) => e.name == j['homeTab']).firstOrNull ??
          HomeTab.routines,
    );
  }
}
