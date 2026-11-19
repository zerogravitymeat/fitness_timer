import 'dart:async';

import 'package:path_provider/path_provider.dart';

import '../services/billing/billing_service.dart';
import '../services/billing/entitlement_service.dart';
import '../services/run/run_snapshot_store.dart';
import '../services/storage/routine_repository.dart';
import '../services/storage/routine_store.dart';
import '../services/storage/settings_store.dart';

/// 앱 전체에서 하나만 쓰는 객체들. main()에서 한 번 초기화한다.
abstract final class AppServices {
  static late final String dataDir;
  static late final RoutineStore routines;
  static late final SettingsStore settings;
  static late final RunSnapshotStore runSnapshots;
  static late final EntitlementService entitlement;
  static late final BillingService billing;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    dataDir = dir.path;
    routines = RoutineStore(RoutineRepository(dir));
    settings = SettingsStore(dataDir);
    runSnapshots = RunSnapshotStore(dataDir);
    entitlement = EntitlementService(dataDir);
    billing = BillingService(entitlement);
    await Future.wait([routines.load(), settings.load(), entitlement.load()]);
    // 구매 내역 확인은 네트워크가 필요하므로 앱 시작을 기다리게 하지 않는다
    unawaited(billing.init());
  }
}
