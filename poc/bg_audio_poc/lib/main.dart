// PoC: 포그라운드 서비스 안에서 타이머 + 비프 + TTS가 동작하는지,
// 그리고 지연/오차가 얼마인지 측정한다. (docs/05_기술_설계.md 10장)
import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  FlutterForegroundTask.initCommunicationPort();
  runApp(const PocApp());
}

// ───────────────────────── 서비스 쪽 ─────────────────────────

@pragma('vm:entry-point')
void startCallback() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(PocHandler());
}

class Cue {
  Cue(this.atMs, this.label, {this.sound, this.speech});
  final int atMs;
  final String label;
  final String? sound;
  final String? speech;
}

/// 한 사이클(67초): 준비 5초 → 횟수 모드 8회(템포 2-0-1) → 휴식 15초 → 운동 20초
const int cycleMs = 67000;
const _koNums = ['하나', '둘', '셋', '넷', '다섯', '여섯', '일곱', '여덟'];

List<Cue> buildCycle(int base) {
  final c = <Cue>[];
  void countdown(int endAt) {
    for (var i = 3; i >= 1; i--) {
      c.add(Cue(base + endAt - i * 1000, 'countdown$i', sound: 'tick', speech: '$i'));
    }
  }

  // 준비 0~5000
  c.add(Cue(base + 0, 'prep', speech: '준비하세요'));
  countdown(5000);
  // 횟수 모드 시작 5000, 템포 시작 6500, 1회 3000ms
  c.add(Cue(base + 5000, 'repsStart', sound: 'long', speech: '8회 시작'));
  const repStart = 6500;
  for (var i = 0; i < 8; i++) {
    final s = repStart + i * 3000;
    c.add(Cue(base + s, 'down${i + 1}', sound: 'low'));
    c.add(Cue(base + s + 2000, 'up${i + 1}', sound: 'high'));
    c.add(Cue(base + s + 3000, 'rep${i + 1}', speech: _koNums[i]));
  }
  // 휴식 30500~45500
  c.add(Cue(base + 30500, 'rest', sound: 'long', speech: '휴식 15초'));
  c.add(Cue(base + 35500, 'rest10', speech: '10초 남았습니다'));
  countdown(45500);
  // 운동 45500~65500
  c.add(Cue(base + 45500, 'work', sound: 'long', speech: '운동 시작'));
  countdown(65500);
  c.add(Cue(base + 65500, 'cycleDone', sound: 'done', speech: '한 사이클 완료'));
  c.sort((a, b) => a.atMs.compareTo(b.atMs));
  return c;
}

String segmentName(int ms) {
  final t = ms % cycleMs;
  if (t < 5000) return '준비';
  if (t < 30500) return '횟수 모드';
  if (t < 45500) return '휴식';
  if (t < 65500) return '운동';
  return '완료';
}

class PocHandler extends TaskHandler {
  final _sw = Stopwatch();
  late DateTime _wallStart;
  Timer? _ticker;
  final _pools = <String, AudioPool>{};
  final _beepContext = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.none,
    ),
  );
  late final FlutterTts _tts;

  final _queue = <Cue>[];
  int _cycle = 0;
  int _lastTick = 0;
  int _lastNotify = -1;
  int _lastDriftLog = 0;

  // 측정값
  final _beepLags = <int>[];
  final _ttsLatencies = <int>[];
  int _gaps = 0;
  int _maxGap = 0;
  int _skipped = 0;
  int _driftMs = 0;
  int _ttsCallAt = -1;
  String _ttsStatus = 'init';

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _log('onStart starter=${starter.name}');
    // 비프는 오디오 포커스를 잡지 않는다 → 다른 앱 음악 위에 겹쳐서 재생
    await AudioPlayer.global.setAudioContext(_beepContext);
    _tts = FlutterTts();
    for (final name in ['low', 'high', 'tick', 'long', 'done']) {
      final file = switch (name) {
        'low' => 'beep_low.wav',
        'high' => 'beep_high.wav',
        'tick' => 'tick.wav',
        'long' => 'beep_long.wav',
        _ => 'done.wav',
      };
      try {
        _pools[name] = await AudioPool.create(
          source: AssetSource(file),
          maxPlayers: 3,
          playerMode: PlayerMode.lowLatency,
          audioContext: _beepContext,
        );
      } catch (e) {
        _log('AUDIO_INIT_FAIL $name $e');
      }
    }
    try {
      final avail = await _tts.isLanguageAvailable('ko-KR');
      await _tts.setLanguage('ko-KR');
      await _tts.setQueueMode(0); // flush: 새 안내가 이전 안내를 끊음
      await _tts.awaitSpeakCompletion(false);
      _tts.setStartHandler(() {
        if (_ttsCallAt >= 0) {
          final lat = _sw.elapsedMilliseconds - _ttsCallAt;
          _ttsLatencies.add(lat);
          _log('TTS_START latency=${lat}ms');
          _ttsCallAt = -1;
        }
      });
      _tts.setErrorHandler((msg) => _log('TTS_ERROR $msg'));
      _ttsStatus = 'ko-KR available=$avail';
      _log('TTS_INIT $_ttsStatus');
    } catch (e) {
      _ttsStatus = 'fail $e';
      _log('TTS_INIT_FAIL $e');
    }

    _wallStart = DateTime.now();
    _sw.start();
    _queue.addAll(buildCycle(0));
    _ticker = Timer.periodic(const Duration(milliseconds: 10), (_) => _tick());
  }

  void _tick() {
    final now = _sw.elapsedMilliseconds;
    final gap = now - _lastTick;
    if (gap > 250) {
      _gaps++;
      _maxGap = max(_maxGap, gap);
      _log('GAP ${gap}ms at $now');
    }
    _lastTick = now;

    while (_queue.isNotEmpty && _queue.first.atMs <= now) {
      final cue = _queue.removeAt(0);
      final lag = now - cue.atMs;
      if (lag > 1000) {
        _skipped++;
        _log('SKIP ${cue.label} lag=${lag}ms');
        continue;
      }
      if (cue.sound != null) {
        _pools[cue.sound]?.start();
        _beepLags.add(lag);
      }
      if (cue.speech != null) {
        _ttsCallAt = now;
        _tts.speak(cue.speech!, focus: true);
      }
      _log('CUE ${cue.label} lag=${lag}ms');
    }
    if (_queue.isEmpty) {
      _cycle++;
      _queue.addAll(buildCycle(_cycle * cycleMs));
    }

    // 1초마다 알림 갱신 + 화면으로 통계 전송
    final sec = now ~/ 1000;
    if (sec != _lastNotify) {
      _lastNotify = sec;
      final mm = (sec ~/ 60).toString().padLeft(2, '0');
      final ss = (sec % 60).toString().padLeft(2, '0');
      FlutterForegroundTask.updateService(
        notificationTitle: 'PoC 진행 중 · ${segmentName(now)}',
        notificationText: '사이클 ${_cycle + 1} · 경과 $mm:$ss',
      );
      FlutterForegroundTask.sendDataToMain(_stats(now));
    }
    // 1분마다 시간 오차 기록
    if (now - _lastDriftLog >= 60000) {
      _lastDriftLog = now;
      final wall = DateTime.now().difference(_wallStart).inMilliseconds;
      _driftMs = wall - now;
      _log('DRIFT elapsed=${now}ms wall=${wall}ms diff=${_driftMs}ms');
    }
  }

  Map<String, Object> _stats(int now) {
    String summary(List<int> xs) {
      if (xs.isEmpty) return '-';
      final s = [...xs]..sort();
      final avg = s.reduce((a, b) => a + b) / s.length;
      final p95 = s[min(s.length - 1, (s.length * 0.95).floor())];
      return 'n=${s.length} 평균 ${avg.toStringAsFixed(1)} · p95 $p95 · 최대 ${s.last} ms';
    }

    return {
      'elapsed': now,
      'segment': segmentName(now),
      'cycle': _cycle + 1,
      'beep': summary(_beepLags),
      'tts': summary(_ttsLatencies),
      'tts_status': _ttsStatus,
      'drift': _driftMs,
      'gaps': '$_gaps회 (최대 $_maxGap ms)',
      'skipped': _skipped,
    };
  }

  void _log(String m) {
    // ignore: avoid_print
    print('POC| ${_sw.elapsedMilliseconds} | $m');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _log('onDestroy isTimeout=$isTimeout');
    _ticker?.cancel();
    try {
      await _tts.stop();
    } catch (_) {}
    for (final p in _pools.values) {
      await p.dispose();
    }
  }
}

// ───────────────────────── 화면 쪽 ─────────────────────────

class PocApp extends StatelessWidget {
  const PocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BG Audio PoC',
      theme: ThemeData.dark(useMaterial3: true),
      home: const PocPage(),
    );
  }
}

class PocPage extends StatefulWidget {
  const PocPage({super.key});

  @override
  State<PocPage> createState() => _PocPageState();
}

class _PocPageState extends State<PocPage> {
  Map<String, Object?> _stats = {};
  bool _running = false;

  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.addTaskDataCallback(_onData);
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'poc_run',
        channelName: '운동 진행',
        channelDescription: '운동 타이머가 진행 중일 때 표시됩니다',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    FlutterForegroundTask.isRunningService.then((r) => setState(() => _running = r));
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    super.dispose();
  }

  void _onData(Object data) {
    if (data is Map) setState(() => _stats = Map<String, Object?>.from(data));
  }

  Future<void> _start() async {
    final perm = await FlutterForegroundTask.checkNotificationPermission();
    if (perm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    final r = await FlutterForegroundTask.startService(
      serviceId: 300,
      serviceTypes: [ForegroundServiceTypes.specialUse],
      notificationTitle: 'PoC 시작',
      notificationText: '준비 중',
      callback: startCallback,
    );
    setState(() => _running = r is ServiceRequestSuccess);
  }

  Future<void> _stop() async {
    await FlutterForegroundTask.stopService();
    setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final e = (_stats['elapsed'] as int?) ?? 0;
    final rows = <(String, String)>[
      ('경과', '${e ~/ 60000}분 ${(e % 60000) ~/ 1000}초'),
      ('구간', '${_stats['segment'] ?? '-'} (사이클 ${_stats['cycle'] ?? '-'})'),
      ('비프 지연', '${_stats['beep'] ?? '-'}'),
      ('TTS 시작 지연', '${_stats['tts'] ?? '-'}'),
      ('TTS 상태', '${_stats['tts_status'] ?? '-'}'),
      ('시간 오차', '${_stats['drift'] ?? '-'} ms (1분마다 갱신)'),
      ('tick 끊김', '${_stats['gaps'] ?? '-'}'),
      ('건너뛴 알림', '${_stats['skipped'] ?? '-'}'),
    ];
    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(title: const Text('백그라운드 오디오 PoC')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final (k, v) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 110, child: Text(k, style: const TextStyle(color: Colors.white70))),
                    Expanded(child: Text(v)),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _running ? _stop : _start,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
              child: Text(_running ? '중지' : '시작', style: const TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }
}
