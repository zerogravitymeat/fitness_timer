import 'routine.dart';

/// 프리셋 4개 (docs/02_기능_명세.md 4장). 수정할 수 없고 파일에 저장하지 않는다.
abstract final class Presets {
  static const tabata = Routine(
    id: 'preset_tabata',
    name: '타바타',
    isPreset: true,
    prepMs: 10000,
    workMs: 20000,
    restMs: 10000,
    rounds: 8,
  );

  static const hiit = Routine(
    id: 'preset_hiit',
    name: 'HIIT',
    isPreset: true,
    prepMs: 10000,
    workMs: 40000,
    restMs: 20000,
    rounds: 8,
  );

  static const plank = Routine(
    id: 'preset_plank',
    name: '플랭크',
    isPreset: true,
    prepMs: 10000,
    workMs: 30000,
    restMs: 30000,
    rounds: 3,
  );

  static const strength = Routine(
    id: 'preset_strength',
    name: '근력 세트',
    isPreset: true,
    endCondition: EndCondition.reps,
    prepMs: 10000,
    targetReps: 15,
    tempo: Tempo.normal,
    restMs: 90000,
    rounds: 3,
  );

  static const all = [tabata, hiit, plank, strength];
}
