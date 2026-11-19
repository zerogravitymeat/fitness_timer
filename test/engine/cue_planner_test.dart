import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_timer/engine/cue.dart';
import 'package:fitness_timer/engine/cue_planner.dart';
import 'package:fitness_timer/engine/routine_compiler.dart';
import 'package:fitness_timer/engine/segment.dart';
import 'package:fitness_timer/models/presets.dart';
import 'package:fitness_timer/models/routine.dart';

List<Cue> _plan(
  Routine r,
  Segment s, {
  CueSettings settings = const CueSettings(),
}) => CuePlanner.plan(r, s, durationMs: s.durationMs, settings: settings);

Map<int, String?> _speech(List<Cue> cues) => {
  for (final c in cues) c.offsetMs: c.speech,
};

void main() {
  group('시간 모드', () {
    final tabata = RoutineCompiler.compile(Presets.tabata);

    test('준비 구간: 비프 없이 "준비하세요", 종료 3·2·1', () {
      final cues = _plan(Presets.tabata, tabata[0]);
      expect(cues.first.sound, isNull);
      expect(_speech(cues), {0: '준비하세요', 7000: '3', 8000: '2', 9000: '1'});
    });

    test('운동 구간: 라운드 번호를 앞에 붙인다', () {
      final round3 = tabata.firstWhere(
        (s) => s.type == SegmentType.work && s.round == 3,
      );
      final cues = _plan(Presets.tabata, round3);
      expect(cues.first.speech, '3라운드, 운동 시작');
      expect(cues.first.sound, CueSound.long);
      expect(
        cues.where((c) => c.kind == CueKind.countdown).map((c) => c.offsetMs),
        [17000, 18000, 19000],
      );
    });

    test('2세트 첫 라운드는 세트 번호도 붙인다', () {
      const r = Routine(id: 'a', name: 'a', rounds: 2, sets: 2);
      final s = RoutineCompiler.compile(r)
          .firstWhere((e) => e.type == SegmentType.work && e.set == 2);
      expect(_plan(r, s).first.speech, '2세트, 1라운드, 운동 시작');
    });

    test('운동 60초 이상이면 절반 안내', () {
      const r = Routine(id: 'a', name: 'a', workMs: 60000, rounds: 1);
      final w = RoutineCompiler.compile(r)
          .firstWhere((e) => e.type == SegmentType.work);
      expect(_speech(_plan(r, w))[30000], '절반 지났습니다');

      const short = Routine(id: 'b', name: 'b', workMs: 59000, rounds: 1);
      final w2 = RoutineCompiler.compile(short)
          .firstWhere((e) => e.type == SegmentType.work);
      expect(_plan(short, w2).any((c) => c.kind == CueKind.halfway), isFalse);
    });

    test('휴식 20초 이상이면 "10초 남았습니다", 10초 휴식은 없음', () {
      final hiitRest = RoutineCompiler.compile(Presets.hiit)
          .firstWhere((e) => e.type == SegmentType.rest);
      final cues = _plan(Presets.hiit, hiitRest);
      expect(cues.first.speech, '휴식 20초');
      expect(_speech(cues)[10000], '10초 남았습니다');

      final tabataRest = tabata.firstWhere((e) => e.type == SegmentType.rest);
      expect(
        _plan(
          Presets.tabata,
          tabataRest,
        ).any((c) => c.kind == CueKind.tenSecondsLeft),
        isFalse,
      );
    });

    test('세트 간 휴식 안내', () {
      const r = Routine(
        id: 'a',
        name: 'a',
        rounds: 2,
        sets: 2,
        setRestMs: 60000,
      );
      final s = RoutineCompiler.compile(r)
          .firstWhere((e) => e.type == SegmentType.setRest);
      expect(_plan(r, s).first.speech, '1세트 완료, 휴식 1분');
    });

    test('카운트다운 설정: 5초 / 없음', () {
      final w = tabata[1];
      expect(
        _plan(
          Presets.tabata,
          w,
          settings: const CueSettings(countdownSeconds: 5),
        ).where((c) => c.kind == CueKind.countdown).map((c) => c.speech),
        ['5', '4', '3', '2', '1'],
      );
      expect(
        _plan(
          Presets.tabata,
          w,
          settings: const CueSettings(countdownSeconds: 0),
        ).any((c) => c.kind == CueKind.countdown),
        isFalse,
      );
    });
  });

  group('횟수 모드 (근력 세트 12회, 2-0-1)', () {
    final segs = RoutineCompiler.compile(Presets.strength);
    final work1 = segs[1];
    final work2 = segs[3];

    test('구간 시작: 긴 비프 + "12회 시작", 세트 번호는 "세트"로', () {
      expect(_plan(Presets.strength, work1).first.speech, '1세트, 12회 시작');
      expect(_plan(Presets.strength, work2).first.speech, '2세트, 12회 시작');
      expect(_plan(Presets.strength, work1).first.sound, CueSound.long);
    });

    test('박자: 올라오기 높은 비프, 다음 회차 내려가기 낮은 비프 + 회차 숫자', () {
      final cues = {
        for (final c in _plan(Presets.strength, work1)) c.offsetMs: c,
      };
      expect(cues[2000]!.sound, CueSound.high);
      expect(cues[3000]!.sound, CueSound.low);
      expect(cues[3000]!.speech, '하나');
      expect(cues[6000]!.speech, '둘');
    });

    test('남은 3회 시점에 "마지막 3회", 마지막 회차 완료는 다음 구간이 대신', () {
      final s = _speech(_plan(Presets.strength, work1));
      expect(s[27000], '마지막 3회'); // 9회 완료
      expect(s[30000], '열'); // 10회 완료
      expect(s[33000], '열하나');
      expect(s.containsKey(36000), isFalse);
    });

    test('종료 카운트다운은 없다', () {
      expect(
        _plan(Presets.strength, work1).any((c) => c.kind == CueKind.countdown),
        isFalse,
      );
    });

    test('동작 + 숫자: 같은 시점 안내는 한 문장으로 합친다', () {
      const r = Routine(
        id: 'a',
        name: 'a',
        endCondition: EndCondition.reps,
        targetReps: 5,
        rounds: 1,
        cueStyle: CueStyle.actionAndNumbers,
      );
      final w = RoutineCompiler.compile(r).firstWhere((e) => e.isRepWork);
      final s = _speech(_plan(r, w));
      expect(s[2000], '올라오고');
      expect(s[3000], '하나, 내려가고');
    });

    test('비프만: 회차 숫자를 읽지 않는다', () {
      const r = Routine(
        id: 'a',
        name: 'a',
        endCondition: EndCondition.reps,
        targetReps: 8,
        rounds: 1,
        cueStyle: CueStyle.beepOnly,
      );
      final w = RoutineCompiler.compile(r).firstWhere((e) => e.isRepWork);
      final cues = _plan(r, w);
      expect(cues.skip(1).every((c) => c.speech == null), isTrue);
      expect(cues[1].sound, isNotNull);
    });

    test('세트 간 휴식으로 안내 (내부적으로는 휴식 구간)', () {
      expect(
        _plan(Presets.strength, segs[2]).first.speech,
        '1세트 완료, 휴식 1분 30초',
      );
    });

    test('목표 횟수 5회 이하면 "마지막 3회" 없이 숫자만', () {
      const r = Routine(
        id: 'a',
        name: 'a',
        endCondition: EndCondition.reps,
        targetReps: 5,
        rounds: 1,
      );
      final w = RoutineCompiler.compile(r).firstWhere((e) => e.isRepWork);
      expect(_plan(r, w).any((c) => c.kind == CueKind.lastReps), isFalse);
    });
  });

  test('완료 안내는 실제 걸린 시간을 읽는다', () {
    expect(CuePlanner.finished(750000).speech, '운동 완료. 총 12분 30초');
  });
}
