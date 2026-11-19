/// 화면 ↔ 서비스 메시지 이름 (docs/05_기술_설계.md 2.1절)
abstract final class RunProtocol {
  static const routineKey = 'run.routine';
  static const soundDirKey = 'run.soundDir';
  static const settingsKey = 'run.settings';
  static const dataDirKey = 'run.dataDir';

  /// 이어하기일 때만 값이 있다 (EngineCheckpoint JSON). 없으면 빈 문자열.
  static const restoreKey = 'run.restore';

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
