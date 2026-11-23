import 'dart:convert';
import 'dart:io';

import 'package:fitness_timer/engine/timer_core.dart';
import 'package:fitness_timer/models/app_settings.dart';
import 'package:fitness_timer/models/presets.dart';
import 'package:fitness_timer/models/workout.dart';
import 'package:fitness_timer/services/run/run_snapshot_store.dart';
import 'package:fitness_timer/services/storage/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('언어: 저장·복원, 지원하지 않는 값은 기기 언어(null)', () {
    const s = AppSettings();
    expect(s.language, isNull);
    final en = s.withLanguage('en');
    expect(AppSettings.fromJson(en.toJson()).language, 'en');
    expect(en.copyWith(sound: false).language, 'en');
    expect(en.withLanguage(null).language, isNull);
    expect(s.withLanguage('fr').language, isNull);
    expect(AppSettings.fromJson({'language': 'fr'}).language, isNull);
  });

  test('음성: 언어별 저장·복원, null이면 기본 음성', () {
    final s = const AppSettings()
        .withVoice('ko-KR', 'ko-kr-x-ism-local')
        .withVoice('en-US', 'en-us-x-iol-local');
    final back = AppSettings.fromJson(s.toJson());
    expect(back.voices, {
      'ko-KR': 'ko-kr-x-ism-local',
      'en-US': 'en-us-x-iol-local',
    });
    expect(back.withLanguage('en').voices, back.voices);
    expect(back.withVoice('ko-KR', null).voices, {
      'en-US': 'en-us-x-iol-local',
    });
    expect(const AppSettings().voices, isEmpty);
    expect(AppSettings.fromJson({'voices': 'x'}).voices, isEmpty);
    expect(
      AppSettings.fromJson({
        'voices': {'ko-KR': 3, 'en-US': 'a'},
      }).voices,
      {'en-US': 'a'},
    );
  });

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
      await s.save(Workout.single(Presets.tabata), cp, '라운드 1/8');
      final saved = await s.load();
      expect(saved!.workout.routines.single.id, Presets.tabata.id);
      expect(saved.workout.isCourse, isFalse);
      expect(saved.checkpoint.segmentIndex, 2);
      expect(saved.progressLabel, '라운드 1/8');
      await s.clear();
      expect(await s.load(), isNull);
    });

    test('30분이 지나면 이어하기 대상에서 빼고 지운다', () async {
      var now = 1000;
      final s = RunSnapshotStore(dir.path, now: () => now);
      await s.save(Workout.single(Presets.tabata), cp, '');
      now += const Duration(minutes: 31).inMilliseconds;
      expect(await s.load(), isNull);
      now = 1000;
      expect(await s.load(), isNull); // 이미 지워짐
    });

    test('저장 직후 지우기를 불러도 파일이 되살아나지 않는다', () async {
      final s = RunSnapshotStore(dir.path);
      // 기다리지 않고 연달아 호출 (서비스에서 운동이 끝나는 순간과 같은 상황)
      s.save(Workout.single(Presets.tabata), cp, '');
      s.save(Workout.single(Presets.tabata), cp, '');
      await s.clear();
      expect(await s.load(), isNull);
      expect(
        File('${dir.path}/${RunSnapshotStore.fileName}').existsSync(),
        isFalse,
      );
    });

    test('코스 기능 전 형식(루틴 하나)도 읽는다', () async {
      await File('${dir.path}/${RunSnapshotStore.fileName}').writeAsString(
        jsonEncode({
          'routine': Presets.hiit.toJson(),
          'checkpoint': cp.toJson(),
          'savedAt': 1000,
          'progress': '라운드 2/8',
        }),
      );
      final saved = await RunSnapshotStore(dir.path, now: () => 2000).load();
      expect(saved!.workout.routines.single.id, Presets.hiit.id);
      expect(saved.workout.name, Presets.hiit.name);
    });

    test('코스 저장 → 불러오기', () async {
      final s = RunSnapshotStore(dir.path, now: () => 1000);
      final w = Workout(
        name: '아침 코스',
        routines: [Presets.tabata, Presets.plank],
        restsMs: [45000],
        courseId: 'c1',
      );
      await s.save(w, cp, '');
      final saved = await s.load();
      expect(saved!.workout.isCourse, isTrue);
      expect(saved.workout.name, '아침 코스');
      expect(saved.workout.routines.map((r) => r.id), [
        Presets.tabata.id,
        Presets.plank.id,
      ]);
      expect(saved.workout.restsMs, [45000]);
    });

    test('깨진 파일은 null', () async {
      await File('${dir.path}/${RunSnapshotStore.fileName}')
          .writeAsString('{oops');
      expect(await RunSnapshotStore(dir.path).load(), isNull);
    });
  });
}
