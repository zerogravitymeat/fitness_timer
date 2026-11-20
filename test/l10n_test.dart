import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_timer/features/common/routine_summary.dart';
import 'package:fitness_timer/l10n/l10n.dart';
import 'package:fitness_timer/models/presets.dart';
import 'package:fitness_timer/services/run/run_labels.dart';
import 'package:fitness_timer/services/storage/routine_store.dart';

void main() {
  test('기기 언어를 따르고, 지원하지 않는 언어면 영어', () {
    expect(resolveLocale(const Locale('ko', 'KR')), const Locale('ko'));
    expect(resolveLocale(const Locale('en', 'GB')), const Locale('en'));
    expect(resolveLocale(const Locale('fr')), const Locale('en'));
    expect(resolveLocale(null), const Locale('en'));
  });

  group('영어 문구', () {
    final en = l10nFor(const Locale('en'));

    test('시간·횟수 표기와 복수형', () {
      expect(RunLabels.duration(en, 90000), '1 min 30s');
      expect(RunLabels.duration(en, 20000), '20s');
      expect(en.repsCount(1), '1 rep');
      expect(en.repsCount(12), '12 reps');
      expect(RoutineSummary.of(en, Presets.strength), '15 reps × 3 sets · 2-0-1');
    });

    test('프리셋 이름은 id로 번역한다', () {
      expect(presetName(en, Presets.plank), 'Plank');
      expect(presetName(l10nFor(const Locale('ko')), Presets.plank), '플랭크');
    });

    test('사본 이름은 길이 제한 안에서 자른다', () {
      final name = RoutineStore.copyName('a' * 40, en.copyName);
      expect(name.endsWith(' copy'), isTrue);
      expect(name.length, lessThanOrEqualTo(20));
    });
  });
}
