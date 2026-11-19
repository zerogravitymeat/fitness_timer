import 'package:flutter/foundation.dart';

import '../../models/app_settings.dart';
import 'json_file.dart';

/// 앱 설정 (docs/03 S5). `settings.json`에 저장한다.
class SettingsStore extends ChangeNotifier {
  SettingsStore(String dir) : _file = JsonFile('$dir/$fileName');

  static const fileName = 'settings.json';
  final JsonFile _file;
  AppSettings _s = const AppSettings();
  Future<void> _saving = Future.value();

  AppSettings get value => _s;

  Future<void> load() async {
    final j = await _file.read();
    _s = j == null ? const AppSettings() : AppSettings.fromJson(j);
    notifyListeners();
  }

  Future<void> update(AppSettings s) {
    _s = s;
    notifyListeners();
    return _saving = _saving.then((_) => _file.write(s.toJson())).catchError((
      Object e,
    ) {
      debugPrint('SettingsStore: 저장 실패 $e');
    });
  }
}
