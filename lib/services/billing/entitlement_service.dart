import 'package:flutter/foundation.dart';

import '../../models/entitlement.dart';
import '../storage/json_file.dart';
import 'trial_store.dart';

/// 화면이 쓰는 이용 상태. 무료 체험 횟수(서비스가 씀)와 구매 상태(결제가 씀)를 합친다.
class EntitlementService extends ChangeNotifier {
  EntitlementService(String dir)
    : trial = TrialStore(dir),
      _purchaseCache = JsonFile('$dir/purchase.json');

  final TrialStore trial;

  /// 마지막으로 확인한 구매 상태. 오프라인일 때 이 값을 쓴다 (docs/02 10.5절)
  final JsonFile _purchaseCache;

  bool _isFull = false;
  int _freeUsed = 0;
  int _usedAtRunStart = 0;

  /// 개발용: 결제 없이 정식 버전으로 보이게 한다 (디버그 빌드에서만)
  bool _debugForceFull = false;

  Entitlement get value =>
      Entitlement(isFull: _isFull || _debugForceFull, freeUsed: _freeUsed);

  bool get debugForceFull => _debugForceFull;

  Future<void> load() async {
    final cache = await _purchaseCache.read();
    _isFull = cache?['isFull'] as bool? ?? false;
    _freeUsed = await trial.read();
    notifyListeners();
  }

  /// 서비스가 차감한 값을 다시 읽는다 (결과 화면, 앱으로 돌아왔을 때)
  Future<void> refreshTrial() async {
    final v = await trial.read();
    if (v != _freeUsed) {
      _freeUsed = v;
      notifyListeners();
    }
  }

  /// 운동을 시작할 때 부른다. 결과 화면에서 이번 운동이 차감됐는지 비교한다.
  void markRunStart() => _usedAtRunStart = _freeUsed;

  TrialNotice? noticeAfterRun() =>
      value.noticeAfterRun(usedBefore: _usedAtRunStart);

  /// 결제 쪽에서 Google Play 확인 결과를 알려준다
  Future<void> setFull(bool full) async {
    final changed = full != _isFull;
    _isFull = full;
    await _purchaseCache.write({
      'isFull': full,
      'verifiedAt': DateTime.now().millisecondsSinceEpoch,
    });
    if (changed) notifyListeners();
  }

  // ── 개발용 (kDebugMode에서만 화면에 노출) ──

  void setDebugForceFull(bool v) {
    if (!kDebugMode) return;
    _debugForceFull = v;
    notifyListeners();
  }

  Future<void> setDebugFreeUsed(int used) async {
    if (!kDebugMode) return;
    await trial.setForDebug(used);
    _freeUsed = used;
    notifyListeners();
  }
}
