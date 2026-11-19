import 'dart:io';

import 'package:fitness_timer/engine/timer_core.dart';
import 'package:fitness_timer/models/app_settings.dart';
import 'package:fitness_timer/models/presets.dart';
import 'package:fitness_timer/services/run/run_snapshot_store.dart';
import 'package:fitness_timer/services/storage/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('ft_test'));
  tearDown(() => dir.delete(recursive: true));

  group('AppSettings', () {
    test('기본값 (docs/02 6.3절)', () {
      const s = AppSettings();
      expect(
        (
          s.sound,
          s.vibration,
          s.voice,
          s.countdownSeconds,
          s.speechSpeed,
          s.keepScreenOn,
        ),
        (true, true, true, 3, SpeechSpeed.normal, true),
      );
    });

    test('JSON 왕복, 이상한 값은 기본값', () {
      const s = AppSettings(
        sound: false,
        countdownSeconds: 5,
        speechSpeed: SpeechSpeed.fast,
      );
      expect(AppSettings.fromJson(s.toJson()).toJson(), s.toJson());
      final bad = AppSettings.fromJson({
        'countdownSeconds': 4,
        'speechSpeed': 'warp',
      });
      expect(bad.countdownSeconds, 3);
      expect(bad.speechSpeed, SpeechSpeed.normal);
    });

    test('SettingsStore: 저장 후 다시 불러오기', () async {
      final a = SettingsStore(dir.path);
      await a.load();
      await a.update(a.value.copyWith(voice: false, keepScreenOn: false));
      final b = SettingsStore(dir.path);
      await b.load();
      expect(b.value.voice, isFalse);
      expect(b.value.keepScreenOn, isFalse);
    });
  });

  group('RunSnapshotStore', () {
    const cp = EngineCheckpoint(
      segmentIndex: 2,
      segmentElapsedMs: 4000,
      extraMs: 0,
      totalActiveMs: 34000,
      trialCounted: false,
    );

    test('저장 → 불러오기 → 지우기', () async {
      var now = 1000;
      final s = RunSnapshotStore(dir.path, now: () => now);
      await s.save(Presets.tabata, cp, '라운드 1/8');
      final saved = await s.load();
      expect(saved!.routine.id, Presets.tabata.id);
      expect(saved.checkpoint.segmentIndex, 2);
      expect(saved.progressLabel, '라운드 1/8');
      await s.clear();
      expect(await s.load(), isNull);
    });

    test('30분이 지나면 이어하기 대상에서 빼고 지운다', () async {
      var now = 1000;
      final s = RunSnapshotStore(dir.path, now: () => now);
      await s.save(Presets.tabata, cp, '');
      now += const Duration(minutes: 31).inMilliseconds;
      expect(await s.load(), isNull);
      now = 1000;
      expect(await s.load(), isNull); // 이미 지워짐
    });

    test('저장 직후 지우기를 불러도 파일이 되살아나지 않는다', () async {
      final s = RunSnapshotStore(dir.path);
      // 기다리지 않고 연달아 호출 (서비스에서 운동이 끝나는 순간과 같은 상황)
      s.save(Presets.tabata, cp, '');
      s.save(Presets.tabata, cp, '');
      await s.clear();
      expect(await s.load(), isNull);
      expect(
        File('${dir.path}/${RunSnapshotStore.fileName}').existsSync(),
        isFalse,
      );
    });

    test('깨진 파일은 null', () async {
      await File('${dir.path}/${RunSnapshotStore.fileName}')
          .writeAsString('{oops');
      expect(await RunSnapshotStore(dir.path).load(), isNull);
    });
  });
}
