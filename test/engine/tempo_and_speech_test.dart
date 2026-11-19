import 'package:flutter_test/flutter_test.dart';
import 'package:health_timer/engine/korean_speech.dart';
import 'package:health_timer/engine/tempo_clock.dart';
import 'package:health_timer/models/routine.dart';

void main() {
  group('TempoClock', () {
    test('2-0-1: 멈춤 0초는 건너뛴다', () {
      const t = Tempo.normal;
      expect(TempoClock.phases(t).map((e) => e.$1), [
        TempoPhase.down,
        TempoPhase.up,
      ]);

      var p = TempoClock.at(t, 12, 0);
      expect(
        (p.completedReps, p.phase, p.currentRep(12)),
        (0, TempoPhase.down, 1),
      );

      p = TempoClock.at(t, 12, 2000);
      expect((p.completedReps, p.phase), (0, TempoPhase.up));

      p = TempoClock.at(t, 12, 3000);
      expect(
        (p.completedReps, p.phase, p.currentRep(12)),
        (1, TempoPhase.down, 2),
      );
    });

    test('3-1-2: 멈춤 단계', () {
      const t = Tempo.slow;
      final p = TempoClock.at(t, 10, 3500);
      expect(
        (p.phase, p.phaseElapsedMs, p.phaseDurationMs),
        (TempoPhase.hold, 500, 1000),
      );
    });

    test('목표 횟수를 다 채우면 완료 상태', () {
      final p = TempoClock.at(Tempo.normal, 12, 36000);
      expect(p.completedReps, 12);
      expect(p.currentRep(12), 12);
    });

    test('템포 표기', () {
      expect(Tempo.normal.label, '2-0-1');
      expect(const Tempo(downMs: 1500, holdMs: 0, upMs: 1000).label, '1.5-0-1');
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
