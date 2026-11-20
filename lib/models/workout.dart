// 순수 Dart 모델. Flutter를 import하지 않는다 (docs/05_기술_설계.md 8장).
import 'course.dart';
import 'routine.dart';

/// 타이머가 실제로 진행하는 것: 루틴 하나, 또는 코스(루틴 여러 개 + 사이 휴식).
/// 엔진과 서비스, 이어하기 저장은 모두 이 단위로 다룬다 (docs/05 3장).
class Workout {
  const Workout({
    required this.name,
    required this.routines,
    this.restsMs = const [],
    this.courseId,
  });

  /// 루틴 하나
  Workout.single(Routine r) : this(name: r.name, routines: [r]);

  /// 코스. 찾을 수 없는 루틴(지워진 루틴)은 건너뛴다.
  factory Workout.course(Course c, Routine? Function(String id) lookup) {
    final routines = <Routine>[];
    final rests = <int>[];
    for (final s in c.normalized().steps) {
      final r = lookup(s.routineId);
      if (r == null) continue;
      routines.add(r);
      rests.add(s.restAfterMs);
    }
    if (rests.isNotEmpty) rests.removeLast();
    return Workout(
      name: c.name,
      routines: routines,
      restsMs: rests,
      courseId: c.id,
    );
  }

  final String name;

  /// 진행할 루틴들 (1개 이상이어야 시작할 수 있다)
  final List<Routine> routines;

  /// `routines[i]`가 끝난 뒤 쉬는 시간. 길이는 `routines.length - 1`. 0이면 바로 이어간다.
  final List<int> restsMs;

  /// 코스이면 코스 id
  final String? courseId;

  bool get isCourse => courseId != null;

  /// 이어하기 확인·잠금 판단용: 코스가 아니면 그 루틴
  Routine? get singleRoutine => isCourse ? null : routines.firstOrNull;

  int restAfter(int i) => i < restsMs.length ? restsMs[i] : 0;

  /// 허용 범위로 맞춘 사본
  Workout normalized() => Workout(
    name: name,
    routines: [for (final r in routines) r.normalized()],
    restsMs: [
      for (var i = 0; i < routines.length - 1; i++)
        restAfter(i).clamp(0, CourseLimits.maxRestMs),
    ],
    courseId: courseId,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'routines': [for (final r in routines) r.toJson()],
    'restsMs': restsMs,
    'courseId': courseId,
  };

  factory Workout.fromJson(Map<String, Object?> j) => Workout(
    name: j['name'] as String? ?? '',
    routines: [
      for (final r in (j['routines'] as List? ?? const []))
        if (r is Map) Routine.fromJson(r.cast<String, Object?>()),
    ],
    restsMs: [
      for (final v in (j['restsMs'] as List? ?? const []))
        if (v is num) v.toInt(),
    ],
    courseId: j['courseId'] as String?,
  );
}
