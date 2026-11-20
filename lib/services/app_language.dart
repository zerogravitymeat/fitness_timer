import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import 'storage/settings_store.dart';

/// 앱 언어 설정을 Android 13+의 "앱별 언어" 설정과 맞춘다.
/// 어느 쪽에서 바꿔도 같은 결과가 나오게 한다.
abstract final class AppLanguage {
  static const _system = MethodChannel('fitness_timer/system');

  /// 시스템 앱별 언어를 설정으로 가져온다 (앱 시작, 앱으로 돌아올 때).
  /// Android 13 미만이면 아무것도 하지 않는다.
  static Future<void> pullFromSystem(SettingsStore store) async {
    final String? tag;
    try {
      tag = await _system.invokeMethod<String>('getAppLocale');
    } catch (_) {
      return;
    }
    if (tag == null) return;
    final code = tag.isEmpty ? null : tag.split(RegExp('[-_]')).first;
    final lang = AppSettings.languageChoices.contains(code) ? code : null;
    if (lang != store.value.language) {
      await store.update(store.value.withLanguage(lang));
    }
  }

  /// 앱 설정에서 언어를 바꿀 때. null이면 기기 언어를 따른다.
  static Future<void> set(SettingsStore store, String? language) async {
    await store.update(store.value.withLanguage(language));
    try {
      await _system.invokeMethod<void>('setAppLocale', language ?? '');
    } catch (_) {}
  }
}
