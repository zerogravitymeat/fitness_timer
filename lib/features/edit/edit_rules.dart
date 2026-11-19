import '../../models/routine.dart';

/// 편집 화면의 값 규칙 (docs/03_화면_설계.md 4장, docs/02 2.1절·3.2절).
/// 화면과 분리해 단위 테스트한다.
abstract final class EditRules {
  /// 시간 스테퍼 한 칸: 60초 미만은 5초, 60초 이상은 15초
  static int timeStep(int ms, {required bool up}) {
    if (up) return ms < 60000 ? 5000 : 15000;
    return ms <= 60000 ? 5000 : 15000;
  }

  /// [ms]에서 한 칸 올리거나 내린 값. 칸 경계에 맞추고 범위 안으로 자른다.
  static int stepTime(
    int ms, {
    required bool up,
    required int min,
    required int max,
  }) {
    final step = timeStep(ms, up: up);
    int next;
    if (up) {
      next = (ms ~/ step + 1) * step;
    } else {
      next = ms % step == 0 ? ms - step : (ms ~/ step) * step;
    }
    return next.clamp(min, max);
  }

  static int stepInt(
    int v, {
    required bool up,
    required int min,
    required int max,
    int step = 1,
  }) => (v + (up ? step : -step)).clamp(min, max);

  /// 템포 한 칸 0.5초
  static int stepTempo(int ms, {required bool up, required int min}) =>
      (ms + (up ? 500 : -500)).clamp(min, RoutineLimits.maxTempoMs);

  /// 이름: 앞뒤 공백 제거, 빈 이름은 저장 불가
  static String? validName(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return t.length > RoutineLimits.maxNameLength
        ? t.substring(0, RoutineLimits.maxNameLength)
        : t;
  }

  /// 시간 → 횟수 모드로 바꿀 때 세트 반복이 사라지는지 (docs/02 2.5절)
  static bool switchingLosesSets(Routine r, EndCondition to) =>
      to == EndCondition.reps &&
      r.endCondition == EndCondition.time &&
      r.sets > 1;

  /// 모드 전환. 횟수 모드는 세트 수 1로 고정한다.
  static Routine switchMode(Routine r, EndCondition to) =>
      r.copyWith(endCondition: to, sets: to == EndCondition.reps ? 1 : r.sets);

  /// 1회 시간이 2.5초 미만이면 "동작 + 숫자" 안내를 쓸 수 없다 (docs/02 3.3절)
  static bool actionCueAllowed(Tempo t) => t.repMs >= 2500;

  /// 새 루틴 기본값 (docs/02 2.1절)
  static Routine blank(String id) => Routine(id: id, name: '내 루틴');
}
