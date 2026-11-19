import 'package:path_provider/path_provider.dart';

import '../services/storage/routine_repository.dart';
import '../services/storage/routine_store.dart';

/// 앱 전체에서 하나만 쓰는 객체들. main()에서 한 번 초기화한다.
abstract final class AppServices {
  static late final RoutineStore routines;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    routines = RoutineStore(RoutineRepository(dir));
    await routines.load();
  }
}
