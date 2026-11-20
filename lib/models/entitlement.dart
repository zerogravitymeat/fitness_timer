// 순수 Dart 모델. Flutter를 import하지 않는다.
import 'routine.dart';
import 'workout.dart';

/// 결과 화면의 체험 안내 종류 (docs/02_기능_명세.md 10.4절)
enum TrialNotice {
  /// "무료 운동 N회 남았어요"
  remaining,

  /// 마지막 무료 운동을 방금 마침
  ended,
}

/// 무료 체험·정식 버전에 따라 쓸 수 있는 기능 (docs/02 10장).
/// 잠금 판단은 이곳 한 곳에서만 한다 (docs/05 7장).
class Entitlement {
  const Entitlement({required this.isFull, required this.freeUsed});

  /// 무료 운동 횟수 (docs/02 10.2절)
  static const freeWorkouts = 15;

  /// 결과 화면에서 남은 횟수를 알려 줄 시점
  static const noticeAt = {5, 3, 1};

  final bool isFull;
  final int freeUsed;

  int get freeRemaining => (freeWorkouts - freeUsed).clamp(0, freeWorkouts);

  /// 체험 중 (정식 버전 아님, 무료 횟수 남음)
  bool get inTrial => !isFull && freeRemaining > 0;

  /// 체험 종료 (정식 버전 아님, 무료 횟수 다 씀)
  bool get trialEnded => !isFull && freeRemaining == 0;

  /// 내 루틴 만들기·수정·실행, 프리셋 복사 (docs/02 10.3절)
  bool get canUseCustom => !trialEnded;

  /// 프리셋은 체험이 끝나도 무료
  bool canStart(Routine r) => r.isPreset || canUseCustom;

  /// 코스는 프리셋만 넣었더라도 내 루틴처럼 잠긴다 (docs/02 10.3절)
  bool canStartWorkout(Workout w) =>
      w.isCourse ? canUseCustom : w.routines.every(canStart);

  /// 운동 하나를 마친 뒤 결과 화면에서 보여줄 안내.
  /// [usedBefore]는 그 운동을 시작하기 전의 사용 횟수.
  TrialNotice? noticeAfterRun({required int usedBefore}) {
    if (isFull || freeUsed <= usedBefore) return null; // 이번 운동은 차감되지 않음
    if (freeRemaining == 0) return TrialNotice.ended;
    if (noticeAt.contains(freeRemaining)) return TrialNotice.remaining;
    return null;
  }
}
