import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// BuildContext 없이 쓸 문구 (서비스 isolate의 알림 등).
/// 지원하지 않는 언어면 기본 언어로.
AppLocalizations l10nFor(Locale locale) {
  final supported = AppLocalizations.supportedLocales;
  final match = supported.firstWhere(
    (s) => s.languageCode == locale.languageCode,
    orElse: () => supported.first,
  );
  return lookupAppLocalizations(match);
}
