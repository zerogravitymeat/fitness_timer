import 'package:fitness_timer/features/edit/edit_rules.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  int up(int ms) => EditRules.stepTime(ms, up: true, min: 0, max: 600000);
  int down(int ms) => EditRules.stepTime(ms, up: false, min: 0, max: 600000);

  test('시간 스테퍼: 60초 미만 5초, 60초 이상 15초', () {
    expect(up(20000), 25000);
    expect(up(55000), 60000);
    expect(up(60000), 75000);
    expect(down(75000), 60000);
    expect(down(60000), 55000);
    expect(down(5000), 0);
  });

  test('시간 스테퍼: 칸 경계가 아닌 값은 가까운 경계로', () {
    expect(up(23000), 25000); // 휠로 23초를 고른 뒤 +
    expect(down(23000), 20000);
    expect(down(62000), 60000);
    expect(up(62000), 75000);
  });

  test('범위를 벗어나지 않는다', () {
    expect(EditRules.stepTime(5000, up: false, min: 5000, max: 10000), 5000);
    expect(EditRules.stepTime(10000, up: true, min: 5000, max: 10000), 10000);
    expect(EditRules.stepInt(1, up: false, min: 1, max: 99), 1);
    expect(EditRules.stepTempo(500, up: false, min: 500), 500);
    expect(EditRules.stepTempo(5000, up: true, min: 500), 5000);
    expect(EditRules.stepTempo(0, up: true, min: 0), 500);
  });

  test('이름: 공백 정리, 빈 이름 거부, 20자 제한', () {
    expect(EditRules.validName('  하체  '), '하체');
    expect(EditRules.validName('   '), isNull);
    expect(EditRules.validName('가' * 25)!.length, 20);
  });

  test('시간 → 횟수 모드: 세트 2 이상이면 확인 필요, 세트는 1로', () {
    const r = Routine(id: 'a', name: 'a', sets: 3);
    expect(EditRules.switchingLosesSets(r, EndCondition.reps), isTrue);
    expect(
      EditRules.switchingLosesSets(r.copyWith(sets: 1), EndCondition.reps),
      isFalse,
    );
    final switched = EditRules.switchMode(r, EndCondition.reps);
    expect(switched.isReps, isTrue);
    expect(switched.sets, 1);
    // 횟수 → 시간은 그대로
    expect(EditRules.switchMode(switched, EndCondition.time).sets, 1);
  });

  test('"동작 + 숫자"는 1회 2.5초 이상일 때만', () {
    expect(EditRules.actionCueAllowed(Tempo.normal), isTrue); // 3초
    expect(EditRules.actionCueAllowed(Tempo.fast), isFalse); // 2초
  });

  test('copyWith / sameSettingsAs', () {
    const r = Routine(id: 'a', name: 'a');
    expect(r.copyWith(rounds: 3).rounds, 3);
    expect(r.sameSettingsAs(r.copyWith(id: 'b')), isTrue);
    expect(r.sameSettingsAs(r.copyWith(rounds: 3)), isFalse);
  });
}
