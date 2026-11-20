import 'package:flutter/widgets.dart';

import '../models/routine.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// 지원하는 언어 중 [locale]에 맞는 것. 없으면 영어.
Locale resolveLocale(Locale? locale) =>
    AppLocalizations.supportedLocales
        .where((s) => s.languageCode == locale?.languageCode)
        .firstOrNull ??
    const Locale('en');

/// BuildContext 없이 쓸 문구 (서비스 isolate의 알림 등)
AppLocalizations l10nFor(Locale locale) =>
    lookupAppLocalizations(resolveLocale(locale));

/// 프리셋 이름 (저장된 이름이 아니라 id로 찾는다)
String presetName(AppLocalizations l, Routine preset) => switch (preset.id) {
  'preset_tabata' => l.presetTabata,
  'preset_hiit' => l.presetHiit,
  'preset_plank' => l.presetPlank,
  'preset_strength' => l.presetStrength,
  _ => preset.name,
};
