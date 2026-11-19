import '../storage/json_file.dart';

/// 무료 운동 사용 횟수 (`trial.json`).
/// 서비스 isolate가 차감하고(쓰기), 화면이 읽는다 (docs/05 5.1절).
///
/// 기기 안에만 저장하므로 앱을 지우고 다시 설치하면 처음부터 다시 셀 수 있다.
/// MVP에서는 감수한다 (docs/02 10.6절).
class TrialStore {
  TrialStore(String dir) : _file = JsonFile('$dir/$fileName');

  static const fileName = 'trial.json';
  final JsonFile _file;
  Future<void> _queue = Future.value();

  Future<int> read() async {
    final j = await _file.read();
    final v = (j?['freeWorkoutsUsed'] as num?)?.toInt() ?? 0;
    return v < 0 ? 0 : v;
  }

  /// 1회 차감. 동시에 여러 번 불려도 하나씩 순서대로 처리한다.
  Future<int> increment() {
    late int result;
    _queue = _queue.then((_) async {
      result = await read() + 1;
      await _file.write({'freeWorkoutsUsed': result});
    });
    return _queue.then((_) => result);
  }

  /// 개발용 (설정 화면의 디버그 메뉴)
  Future<void> setForDebug(int used) =>
      _queue = _queue.then((_) => _file.write({'freeWorkoutsUsed': used}));
}
