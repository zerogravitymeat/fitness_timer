// 순수 Dart 모델. Flutter를 import하지 않는다 (docs/05_기술_설계.md 8장).

/// 코스에 들어간 루틴 하나 (docs/02_기능_명세.md 8-1장).
/// 루틴은 id로 가리킨다. 루틴을 고치면 코스에도 그대로 반영된다.
class CourseStep {
  const CourseStep({required this.routineId, this.restAfterMs = defaultRestMs});

  /// 루틴 사이 휴식 기본값
  static const defaultRestMs = 60000;

  final String routineId;

  /// 이 루틴이 끝나고 다음 루틴 전까지 쉬는 시간. 0이면 휴식 없이 바로 이어간다.
  /// 마지막 루틴의 값은 쓰지 않는다.
  final int restAfterMs;

  CourseStep copyWith({String? routineId, int? restAfterMs}) => CourseStep(
    routineId: routineId ?? this.routineId,
    restAfterMs: restAfterMs ?? this.restAfterMs,
  );

  Map<String, Object?> toJson() => {
    'routineId': routineId,
    'restAfterMs': restAfterMs,
  };

  static CourseStep? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['routineId'];
    if (id is! String || id.isEmpty) return null;
    return CourseStep(
      routineId: id,
      restAfterMs: (j['restAfterMs'] as num?)?.toInt() ?? defaultRestMs,
    );
  }
}

/// 여러 루틴을 정한 순서대로 이어서 하는 묶음 (docs/02_기능_명세.md 8-1장)
class Course {
  const Course({required this.id, required this.name, this.steps = const []});

  final String id;
  final String name;
  final List<CourseStep> steps;

  Course copyWith({String? id, String? name, List<CourseStep>? steps}) =>
      Course(
        id: id ?? this.id,
        name: name ?? this.name,
        steps: steps ?? this.steps,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'steps': [for (final s in steps) s.toJson()],
  };

  factory Course.fromJson(Map<String, Object?> j) => Course(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    steps: [
      for (final s in (j['steps'] as List? ?? const []))
        ?CourseStep.fromJson(s),
    ],
  );

  /// 값을 허용 범위 안으로 맞춘 사본
  Course normalized() => Course(
    id: id,
    name: name,
    steps: [
      for (final s in steps.take(CourseLimits.maxSteps))
        s.copyWith(restAfterMs: s.restAfterMs.clamp(0, CourseLimits.maxRestMs)),
    ],
  );

  /// 설정이 같은지 (편집 화면의 "바뀐 내용 있음" 판단용)
  bool sameAs(Course o) => toJson().toString() == o.toJson().toString();
}

/// 코스 범위 (docs/02_기능_명세.md 8-1장)
abstract final class CourseLimits {
  static const maxSteps = 20;
  static const maxRestMs = 30 * 60 * 1000;
}
