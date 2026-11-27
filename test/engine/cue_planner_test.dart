import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_timer/engine/cue.dart';
import 'package:fitness_timer/engine/cue_planner.dart';
import 'package:fitness_timer/engine/cue_text.dart';
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

  group('횟수 모드 (근력 세트 15회, 1회 3초)', () {
    final segs = RoutineCompiler.compile(Presets.strength);
    final work1 = segs[1];
    final work2 = segs[3];

    test('구간 시작: 첫 회차와 겹치지 않도록 긴 비프만, 음성 없음', () {
      for (final w in [work1, work2]) {
        final start = _plan(Presets.strength, w).first;
        expect(start.offsetMs, 0);
        expect(start.sound, CueSound.long);
        expect(start.speech, isNull);
      }
    });

    test('준비 구간에서 첫 세트와 횟수를 미리 알린다', () {
      expect(_plan(Presets.strength, segs[0]).first.speech, '준비하세요, 1세트 15회');
      const one = Routine(
        id: 'a',
        name: 'a',
        endCondition: EndCondition.reps,
        targetReps: 10,
        rounds: 1,
      );
      final prep = RoutineCompiler.compile(one).first;
      expect(_plan(one, prep).first.speech, '준비하세요, 10회');
    });

    test('회차가 바뀔 때만 낮은 비프 + 회차 숫자, 회차 중간에는 알림 없음', () {
      final cues = {
        for (final c in _plan(Presets.strength, work1)) c.offsetMs: c,
      };
      expect(cues.keys.where((o) => o % 3000 != 0), isEmpty);
      expect(cues[3000]!.sound, CueSound.low);
      expect(cues[3000]!.speech, '하나');
      expect(cues[6000]!.speech, '둘');
    });

    test('회차는 끝까지 숫자로 세고, 마지막 회차 완료는 다음 구간이 대신', () {
      final s = _speech(_plan(Presets.strength, work1));
      expect(s[33000], '열하나');
      expect(s[36000], '열둘');
      expect(s[39000], '열셋');
      expect(s[42000], '열넷');
      expect(s.containsKey(45000), isFalse);
    });

    test('종료 카운트다운은 없다', () {
      expect(
        _plan(Presets.strength, work1).any((c) => c.kind == CueKind.countdown),
        isFalse,
      );
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

    test('세트 간 휴식으로 안내하고 다음 세트와 횟수를 붙인다', () {
      expect(
        _plan(Presets.strength, segs[2]).first.speech,
        '1세트 완료, 휴식 1분 30초, 다음 2세트 15회',
      );
    });

    test('코스: 준비 구간에서 루틴 이름, 루틴 사이 휴식에서 횟수도 읽는다', () {
      expect(
        CuePlanner.plan(
          Presets.strength,
          segs[0],
          durationMs: segs[0].durationMs,
          announceName: true,
        ).first.speech,
        '준비하세요, 근력 세트, 1세트 15회',
      );
      const rest = Segment(
        type: SegmentType.courseRest,
        durationMs: 60000,
        round: 1,
        set: 1,
      );
      expect(
        CuePlanner.plan(
          Presets.strength,
          rest,
          durationMs: 60000,
          announceName: true,
        ).first.speech,
        '휴식 1분, 다음은 근력 세트, 1세트 15회',
      );
    });
  });

  group('영어 음성 안내', () {
    const en = CueSettings(text: EnglishCueText());
    final segs = RoutineCompiler.compile(Presets.strength);

    test('언어 코드로 고르고, 지원하지 않으면 영어', () {
      expect(CueText.forLanguage('ko'), isA<KoreanCueText>());
      expect(CueText.forLanguage('en'), isA<EnglishCueText>());
      expect(CueText.forLanguage('fr'), isA<EnglishCueText>());
    });

    test('횟수 모드: 준비·휴식에서 다음 세트, 회차는 숫자 그대로', () {
      expect(
        _plan(Presets.strength, segs[0], settings: en).first.speech,
        'Get ready, Set 1, 15 reps',
      );
      expect(
        _plan(Presets.strength, segs[2], settings: en).first.speech,
        'Set 1 done, Rest 1 minute 30 seconds, Next, Set 2, 15 reps',
      );
      final s = _speech(_plan(Presets.strength, segs[1], settings: en));
      expect(s[3000], '1');
      expect(s[36000], '12');
    });

    test('시간 모드와 완료 안내', () {
      final tabata = RoutineCompiler.compile(Presets.tabata);
      expect(
        _plan(Presets.tabata, tabata[1], settings: en).first.speech,
        'Round 1, Go',
      );
      expect(
        CuePlanner.finished(750000, text: const EnglishCueText()).speech,
        'Workout complete. Total 12 minutes 30 seconds',
      );
      expect(
        CuePlanner.finished(61000, text: const EnglishCueText()).speech,
        'Workout complete. Total 1 minute 1 second',
      );
    });
  });

  test('완료 안내는 실제 걸린 시간을 읽는다', () {
    expect(CuePlanner.finished(750000).speech, '운동 완료. 총 12분 30초');
  });

  group('1초 소리', () {
    final tabata = RoutineCompiler.compile(Presets.tabata);
    final work = tabata.firstWhere((s) => s.type == SegmentType.work);
    final strength = RoutineCompiler.compile(Presets.strength)[1];
    const time = CueSettings(secondTicksTime: true);
    const reps = CueSettings(secondTicksReps: true);
    Map<int, CueSound?> sounds(List<Cue> cues) => {
      for (final c in cues) c.offsetMs: c.sound,
    };

    test('기본으로는 없다', () {
      expect(
        _plan(Presets.tabata, work).any((c) => c.kind == CueKind.secondTick),
        isFalse,
      );
    });

    test('1초마다 째깍·똑이 번갈아 나고, 구간 끝에는 넣지 않는다', () {
      final s = sounds(_plan(Presets.tabata, work, settings: time));
      expect(s[0], CueSound.long);
      expect(
        [s[1000], s[2000], s[3000]],
        [CueSound.tick, CueSound.tock, CueSound.tick],
      );
      expect(s.keys.toList(), [for (var t = 0; t < 20000; t += 1000) t]);
    });

    test('겹치는 카운트다운은 카운트다운 소리와 음성을 낸다', () {
      final c = _plan(
        Presets.tabata,
        work,
        settings: time,
      ).firstWhere((c) => c.offsetMs == 17000);
      expect(c.kind, CueKind.countdown);
      expect(c.sound, CueSound.short);
      expect(c.speech, '3');
    });

    test('시간 모드와 횟수 모드는 따로 켠다', () {
      bool ticks(Routine r, Segment s, CueSettings c) =>
          _plan(r, s, settings: c).any((c) => c.kind == CueKind.secondTick);
      expect(ticks(Presets.tabata, work, reps), isFalse);
      expect(ticks(Presets.strength, strength, time), isFalse);
      expect(ticks(Presets.strength, strength, reps), isTrue);
    });

    test('횟수 모드: 회차 비프와 겹치면 회차 비프를 낸다', () {
      final s = sounds(_plan(Presets.strength, strength, settings: reps));
      expect(s[1000], CueSound.tick);
      expect(s[2000], CueSound.tock);
      expect(s[3000], CueSound.low);
    });
  });
}
