import '../../engine/timer_core.dart';
import '../../models/routine.dart';
import '../storage/json_file.dart';

/// 이어하기용으로 저장된 진행 상태 (docs/02_기능_명세.md 7장)
class SavedRun {
  const SavedRun({
    required this.routine,
    required this.checkpoint,
    required this.savedAtMs,
    required this.progressLabel,
  });

  final Routine routine;
  final EngineCheckpoint checkpoint;

  /// epoch ms
  final int savedAtMs;

  /// 확인 창에 보여줄 위치. 예: "라운드 3/8"
  final String progressLabel;
}

/// 서비스가 진행 중에 주기적으로 저장하고, 정상적으로 끝나면 지운다.
/// 앱을 다시 열었을 때 남아 있으면 비정상 종료로 본다.
class RunSnapshotStore {
  RunSnapshotStore(String dir, {int Function()? now})
    : _file = JsonFile('$dir/$fileName'),
      _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  static const fileName = 'run_snapshot.json';

  /// 이보다 오래된 상태는 이어하기 대상에서 뺀다 (docs/02 7장)
  static const maxAge = Duration(minutes: 30);

  final JsonFile _file;
  final int Function() _now;

  /// 저장·삭제를 순서대로 처리한다. 저장이 끝나기 전에 삭제가 먼저 끝나면
  /// 끝난 운동의 상태 파일이 되살아나 다음 실행 때 이어하기 창이 잘못 뜬다.
  Future<void> _queue = Future.value();

  Future<void> _enqueue(Future<void> Function() op) =>
      _queue = _queue.then((_) => op()).catchError((Object _) {});

  Future<void> save(Routine routine, EngineCheckpoint c, String progressLabel) {
    final data = {
      'routine': routine.toJson(),
      'checkpoint': c.toJson(),
      'savedAt': _now(),
      'progress': progressLabel,
    };
    return _enqueue(() => _file.write(data));
  }

  /// 30분이 지났거나 깨진 상태는 지우고 null
  Future<SavedRun?> load() async {
    final j = await _file.read();
    if (j == null) return null;
    final savedAt = (j['savedAt'] as num?)?.toInt() ?? 0;
    final routine = j['routine'];
    final cp = j['checkpoint'];
    if (_now() - savedAt > maxAge.inMilliseconds ||
        routine is! Map ||
        cp is! Map) {
      await clear();
      return null;
    }
    return SavedRun(
      routine: Routine.fromJson(routine.cast<String, Object?>()),
      checkpoint: EngineCheckpoint.fromJson(cp.cast<String, Object?>()),
      savedAtMs: savedAt,
      progressLabel: j['progress'] as String? ?? '',
    );
  }

  Future<void> clear() => _enqueue(_file.delete);
}
