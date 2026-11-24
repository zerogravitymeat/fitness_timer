import 'package:fitness_timer/features/edit/edit_rules.dart';
import 'package:fitness_timer/features/edit/name_search.dart';
import 'package:fitness_timer/models/exercise_names.dart';
import 'package:fitness_timer/models/presets.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> find(String q, {List<String> mine = const []}) =>
      NameSearch.search(q, mine: mine, common: ExerciseNames.all, limit: 100);

  test('부분 일치: 앞부분이 맞는 것이 먼저', () {
    final r = find('스쿼');
    expect(r.first, '스쿼트');
    expect(r, containsAll(['점프 스쿼트', '와이드 스쿼트']));
    expect(r.indexOf('스쿼트'), lessThan(r.indexOf('점프 스쿼트')));
  });

  test('초성 검색', () {
    expect(find('ㅅㅋㅌ'), contains('스쿼트'));
    expect(find('ㅍㄹㅋ').first, '플랭크');
    expect(find('ㅂㅍ'), contains('버피'));
  });

  test('초성과 완성 글자를 섞어도 된다', () {
    expect(find('스ㅋ'), contains('스쿼트'));
    expect(find('ㅍ랭'), contains('플랭크'));
  });

  test('입력 중인 마지막 글자', () {
    expect(find('레그커'), contains('레그 컬')); // 받침을 아직 안 침
    expect(find('스쿠'), contains('스쿼트')); // 겹모음을 치는 중
    expect(find('풋'), contains('푸시업')); // 다음 글자 초성이 받침으로 붙음
    expect(find('풋'), isNot(contains('풀업')));
  });

  test('띄어쓰기와 영문 대소문자는 무시', () {
    expect(find('레그컬'), contains('레그 컬'));
    expect(find('hiit'), contains('HIIT'));
  });

  test('내 루틴 이름이 같은 순위에서 먼저, 중복은 한 번만', () {
    final r = find('스', mine: ['스쿼트', '스트레칭 아침']);
    expect(r.take(2), ['스쿼트', '스트레칭 아침']);
    expect(r.where((e) => e == '스쿼트'), hasLength(1));
  });

  test('입력과 똑같은 이름과 빈 입력은 보여주지 않는다', () {
    expect(find('버피'), isNot(contains('버피')));
    expect(find('  '), isEmpty);
  });

  test('없는 이름은 결과 없음', () {
    expect(find('ㅋㅋㅋㅋ'), isEmpty);
  });

  test('운동 이름은 두 언어 모두 최대 길이 이하, 중복 없음', () {
    for (final lang in ['ko', 'en']) {
      final names = ExerciseNames.namesFor(lang);
      expect(names.toSet(), hasLength(names.length), reason: lang);
    }
    for (final n in [...ExerciseNames.all, ...ExerciseNames.namesFor('en')]) {
      expect(
        n.length,
        lessThanOrEqualTo(RoutineLimits.maxNameLength),
        reason: n,
      );
    }
  });

  group('영어', () {
    List<String> findEn(String q) => NameSearch.search(
      q,
      mine: const [],
      common: ExerciseNames.namesFor('en'),
      limit: 100,
    );

    test('영어 이름으로 검색, 하이픈·대소문자 무시', () {
      expect(findEn('squ').first, 'Squat');
      expect(findEn('pushup'), contains('Push-up'));
      expect(findEn('PLANK').first, 'Plank');
    });

    test('영어 이름으로도 같은 기본값을 찾는다', () {
      expect(
        ExerciseNames.defaultsOf('Squat'),
        same(ExerciseNames.defaultsOf('스쿼트')),
      );
      expect(ExerciseNames.defaultsOf('push-up'), isNotNull);
      expect(ExerciseNames.defaultsOf('없는 운동'), isNull);
    });
  });

  group('운동별 기본값', () {
    const base = Routine(id: 'r1', name: '아침 운동');

    test('모든 기본값이 허용 범위 안이다', () {
      for (final e in ExerciseNames.list) {
        final r = e.defaults.applyTo(base);
        expect(r.sameSettingsAs(r.normalized()), isTrue, reason: e.ko);
      }
    });

    test('id와 이름은 그대로, 설정만 바뀐다', () {
      final r = ExerciseNames.defaultsOf('스쿼트')!.applyTo(base);
      expect(r.id, 'r1');
      expect(r.name, '아침 운동');
      expect(r.isReps, isTrue);
      expect(r.targetReps, 15);
      expect(r.tempo, Tempo.normal);
      expect(r.rounds, 3);
      expect(r.restMs, 60000);
    });

    test('시간 모드 예시: 플랭크 30초 / 30초 × 3', () {
      final r = ExerciseNames.defaultsOf('플랭크')!.applyTo(base);
      expect(r.isReps, isFalse);
      expect([r.workMs, r.restMs, r.rounds, r.sets], [30000, 30000, 3, 1]);
    });

    test('기구 고립은 15회', () {
      for (final n in ['레그 컬', '바이셉 컬', '사이드 레터럴 레이즈', '페이스 풀']) {
        expect(
          ExerciseNames.defaultsOf(n)!.applyTo(base).targetReps,
          15,
          reason: n,
        );
      }
    });

    test('타바타·HIIT 기본값은 프리셋과 같다', () {
      for (final p in [Presets.tabata, Presets.hiit]) {
        final r = ExerciseNames.defaultsOf(p.name)!.applyTo(base);
        expect(
          r.sameSettingsAs(
            p.copyWith(id: 'r1', name: '아침 운동', isPreset: false),
          ),
          isTrue,
        );
      }
    });
  });

  group('자동 채우기 조건', () {
    const initial = Routine(id: 'r1', name: '');
    final filled = ExerciseNames.defaultsOf('스쿼트')!.applyTo(initial);

    test('새 루틴이고 설정이 처음 그대로면 채운다 (이름만 바뀐 것도)', () {
      expect(
        EditRules.canAutoFill(
          isNew: true,
          current: initial.copyWith(name: '스'),
          initial: initial,
        ),
        isTrue,
      );
    });

    test('루틴 편집에서는 채우지 않는다', () {
      expect(
        EditRules.canAutoFill(isNew: false, current: initial, initial: initial),
        isFalse,
      );
    });

    test('사용자가 설정을 바꿨으면 채우지 않는다', () {
      final touched = initial.copyWith(rounds: 4);
      expect(
        EditRules.canAutoFill(isNew: true, current: touched, initial: initial),
        isFalse,
      );
      final touchedAfterFill = filled.copyWith(targetReps: 20);
      expect(
        EditRules.canAutoFill(
          isNew: true,
          current: touchedAfterFill,
          initial: initial,
          lastAutoFilled: filled,
        ),
        isFalse,
      );
    });

    test('자동으로 채운 그대로면 다른 추천으로 다시 바꿀 수 있다', () {
      expect(
        EditRules.canAutoFill(
          isNew: true,
          current: filled,
          initial: initial,
          lastAutoFilled: filled,
        ),
        isTrue,
      );
    });
  });
}
