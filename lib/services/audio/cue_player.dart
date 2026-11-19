import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';

import '../../engine/cue.dart';

/// 알림 재생 설정 (docs/02_기능_명세.md 6.3절)
class CuePlayerSettings {
  const CuePlayerSettings({
    this.sound = true,
    this.vibration = true,
    this.voice = true,
    this.speechRate = 0.5,
  });

  final bool sound;
  final bool vibration;
  final bool voice;

  /// flutter_tts 기준 Android 보통 속도 0.5
  final double speechRate;
}

/// 엔진이 낸 [Cue]를 실제 소리·진동·음성으로 재생한다.
/// 포그라운드 서비스 isolate 안에서 쓴다 (docs/05_기술_설계.md 4장, 10.1절).
class CuePlayer {
  CuePlayer({this.settings = const CuePlayerSettings()});

  final CuePlayerSettings settings;

  // 비프는 오디오 포커스를 잡지 않는다 → 다른 앱 음악을 멈추지 않고 겹쳐서 재생.
  // audioplayers 기본값(AUDIOFOCUS_GAIN)은 음악을 멈추게 한다 (PoC 10.1절).
  static final _beepContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  static const _files = {
    CueSound.low: 'beep_low.wav',
    CueSound.high: 'beep_high.wav',
    CueSound.tick: 'tick.wav',
    CueSound.short: 'tick.wav',
    CueSound.long: 'beep_long.wav',
    CueSound.done: 'done.wav',
  };

  final _pools = <CueSound, AudioPool>{};
  FlutterTts? _tts;
  bool _ttsReady = false;
  bool _hasVibrator = false;

  bool get ttsReady => _ttsReady;

  /// 운동 시작 전에 소리를 메모리에 올리고 TTS를 깨워 둔다.
  /// [soundDir]은 메인 isolate가 [SoundFiles.prepare]로 복사해 둔 폴더.
  Future<void> init({required String? soundDir}) async {
    await AudioPlayer.global.setAudioContext(_beepContext);
    // 소리 파일은 동시에 불러온다. 하나씩 기다리면 최악의 경우 시간이 쌓여
    // 화면이 시작 실패로 판단할 수 있다.
    if (soundDir != null) {
      final files = _files.values.toSet();
      final pools = await Future.wait([
        for (final f in files)
          AudioPool.create(
                // AssetSource는 내부에서 path_provider를 써서 서비스 isolate에서 실패한다
                source: DeviceFileSource('$soundDir/$f'),
                maxPlayers: 3,
                playerMode: PlayerMode.lowLatency,
                audioContext: _beepContext,
              )
              .then<AudioPool?>((p) => p)
              .timeout(const Duration(seconds: 3))
              .catchError((Object err) {
                // 소리 하나를 못 불러와도 타이머는 계속 진행한다
                debugPrint('CuePlayer: $f 로딩 실패 $err');
                return null;
              }),
      ]);
      final byFile = Map.fromIterables(files, pools);
      for (final e in _files.entries) {
        final p = byFile[e.value];
        if (p != null) _pools[e.key] = p;
      }
    }
    try {
      final tts = FlutterTts();
      // 일부 기기에서 TTS 엔진 응답이 늦거나 오지 않을 수 있다
      final available = await tts
          .isLanguageAvailable('ko-KR')
          .timeout(const Duration(seconds: 3));
      await tts.setLanguage('ko-KR');
      await tts.setSpeechRate(settings.speechRate);
      await tts.setQueueMode(0); // flush: 새 안내가 이전 안내를 끊는다
      await tts.awaitSpeakCompletion(false);
      _tts = tts;
      _ttsReady = available == true;
    } catch (_) {
      _ttsReady = false; // 음성 없이 비프·진동만으로 진행 (docs/02 6.4절)
    }

    _hasVibrator = await Vibration.hasVibrator()
        .timeout(const Duration(seconds: 1))
        .catchError((Object _) => false);
  }

  void play(Cue cue) {
    final sound = cue.sound;
    if (settings.sound && sound != null) {
      _pools[sound]?.start();
    }
    final vib = cue.vibration;
    if (settings.vibration && vib != null && _hasVibrator) {
      switch (vib) {
        case CueVibration.short:
          Vibration.vibrate(duration: 80);
        case CueVibration.long:
          Vibration.vibrate(duration: 400);
        case CueVibration.double:
          Vibration.vibrate(pattern: [0, 400, 200, 400]);
      }
    }
    final speech = cue.speech;
    if (settings.voice && speech != null && _ttsReady) {
      // focus: true → 말하는 동안만 다른 앱 음악 볼륨을 줄인다
      _tts?.speak(speech, focus: true);
    }
  }

  Future<void> dispose() async {
    try {
      await _tts?.stop();
    } catch (_) {}
    for (final p in _pools.values.toSet()) {
      await p.dispose();
    }
    _pools.clear();
  }
}
