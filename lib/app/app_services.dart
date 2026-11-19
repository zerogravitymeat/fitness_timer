import 'package:path_provider/path_provider.dart';

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

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    dataDir = dir.path;
    routines = RoutineStore(RoutineRepository(dir));
    settings = SettingsStore(dataDir);
    runSnapshots = RunSnapshotStore(dataDir);
    await Future.wait([routines.load(), settings.load()]);
  }
}
