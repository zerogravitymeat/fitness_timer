/// 화면 ↔ 서비스 메시지 이름 (docs/05_기술_설계.md 2.1절)
abstract final class RunProtocol {
  static const routineKey = 'run.routine';
  static const soundDirKey = 'run.soundDir';

  // 화면 → 서비스
  static const cmdPause = 'pause';
  static const cmdResume = 'resume';
  static const cmdNext = 'next';
  static const cmdPrev = 'prev';
  static const cmdAddRest = 'addRest';
  static const cmdStop = 'stop';
  static const cmdView = 'view';

  // 서비스 → 화면
  static const view = 'view';
  static const finished = 'finished';
}
