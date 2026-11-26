import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_timer/engine/korean_speech.dart';
import 'package:fitness_timer/engine/tempo_clock.dart';
import 'package:fitness_timer/models/routine.dart';

void main() {
  group('TempoClock', () {
    test('1회 3초: 회차와 회차 안 위치', () {
      const t = Tempo.normal;
      var p = TempoClock.at(t, 12, 0);
      expect((p.completedReps, p.repElapsedMs, p.currentRep(12)), (0, 0, 1));

      p = TempoClock.at(t, 12, 2000);
      expect((p.completedReps, p.repElapsedMs), (0, 2000));

      p = TempoClock.at(t, 12, 3000);
      expect((p.completedReps, p.repElapsedMs, p.currentRep(12)), (1, 0, 2));
    });

    test('목표 횟수를 다 채우면 완료 상태', () {
      final p = TempoClock.at(Tempo.normal, 12, 36000);
      expect(p.completedReps, 12);
      expect(p.currentRep(12), 12);
    });

    test('템포 표기', () {
      expect(Tempo.normal.seconds, '3');
      expect(const Tempo(2500).seconds, '2.5');
    });
  });

  group('Tempo 저장', () {
    test('1회 시간으로 저장하고 다시 읽는다', () {
      const r = Routine(id: 'a', name: 'a', tempo: Tempo(4500));
      expect(Routine.fromJson(r.toJson()).tempo, const Tempo(4500));
    });

    test('1.3.0까지의 내려가기·멈춤·올라오기 값은 합쳐서 1회 시간으로', () {
      final r = Routine.fromJson({
        'id': 'a',
        'name': 'a',
        'tempo': {'downMs': 3000, 'holdMs': 1000, 'upMs': 2000},
        'cueStyle': 'actionAndNumbers',
      });
      expect(r.tempo, const Tempo(6000));
      // 없어진 "동작 + 숫자" 안내는 숫자만으로
      expect(r.cueStyle, CueStyle.numbersOnly);
    });
  });

  group('KoreanSpeech', () {
    test('고유어 수사', () {
      final cases = {
        1: '하나',
        2: '둘',
        10: '열',
        12: '열둘',
        20: '스물',
        21: '스물하나',
        35: '서른다섯',
        99: '아흔아홉',
        100: '백',
      };
      cases.forEach(
        (n, s) => expect(KoreanSpeech.nativeNumber(n), s, reason: '$n'),
      );
    });

    test('시간 읽기', () {
      expect(KoreanSpeech.duration(20000), '20초');
      expect(KoreanSpeech.duration(60000), '1분');
      expect(KoreanSpeech.duration(90000), '1분 30초');
      expect(KoreanSpeech.duration(750000), '12분 30초');
    });
  });
}
