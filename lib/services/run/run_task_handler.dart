import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../engine/timer_core.dart';
import '../../engine/cue_planner.dart';
import '../../models/app_settings.dart';
import '../../models/routine.dart';
import '../audio/cue_player.dart';
import '../billing/trial_store.dart';
import 'run_labels.dart';
import 'run_protocol.dart';
import 'run_snapshot_store.dart';
import 'run_view.dart';

/// 포그라운드 서비스 진입점. 최상위 함수여야 한다.
@pragma('vm:entry-point')
void runServiceEntryPoint() {
  // 서비스 isolate에서 플러그인을 쓰려면 바인딩을 먼저 초기화해야 한다 (PoC 10.1절)
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(RunTaskHandler());
}

/// 서비스 안에서 엔진을 돌린다 (docs/05_기술_설계.md 2장).
class RunTaskHandler extends TaskHandler {
  static const tickInterval = Duration(milliseconds: 20);
  static const viewInterval = Duration(milliseconds: 500);

  /// 끝난 뒤 완료음·음성이 나올 시간을 주고 서비스를 내린다
  static const finishLinger = Duration(seconds: 4);

  final _stopwatch = Stopwatch();
  TimerCore? _core;
  CuePlayer? _player;
  Timer? _ticker;

  /// 완료 후 서비스를 내리는 예약. 다음 운동이 먼저 시작돼 이 서비스가 내려가면
  /// onDestroy에서 반드시 취소한다. 취소하지 않으면 새로 시작한 운동의 서비스까지 꺼진다.
  Timer? _stopTimer;
  int _lastViewAt = -1 << 30;
  int _lastNotifySec = -1;
  RunStatus? _lastNotifyStatus;
  Finished? _finished;
  RunSnapshotStore? _snapshots;
  TrialStore? _trial;
  int _lastSnapshotAt = 0;
  static const snapshotInterval = Duration(seconds: 5);

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // 시스템이 서비스를 되살린 경우(앱이 강제 종료된 뒤 등)에는 운동을 처음부터
    // 몰래 다시 시작하지 않는다. 저장된 진행 상태는 남겨 두고, 사용자가 앱을 열면
    // 이어하기 확인 창으로 묻는다 (docs/02 7장, docs/03 D1).
    if (starter == TaskStarter.system) {
      await FlutterForegroundTask.stopService();
      return;
    }
    final raw = await FlutterForegroundTask.getData<String>(
      key: RunProtocol.routineKey,
    );
    if (raw == null) {
      await FlutterForegroundTask.stopService();
      return;
    }
    final routine = Routine.fromJson(
      (jsonDecode(raw) as Map).cast<String, Object?>(),
    );
    final settings = await _readJson(RunProtocol.settingsKey);
    final app = settings == null
        ? const AppSettings()
        : AppSettings.fromJson(settings);
    final restore = await _readJson(RunProtocol.restoreKey);
    final dataDir = await FlutterForegroundTask.getData<String>(
      key: RunProtocol.dataDirKey,
    );
    if (dataDir != null) {
      _snapshots = RunSnapshotStore(dataDir);
      _trial = TrialStore(dataDir);
    }

    final player = CuePlayer(
      settings: CuePlayerSettings(
        sound: app.sound,
        vibration: app.vibration,
        voice: app.voice,
        speechRate: app.speechSpeed.ttsRate,
      ),
    );
    await player.init(
      soundDir: await FlutterForegroundTask.getData<String>(
        key: RunProtocol.soundDirKey,
      ),
    );
    _player = player;

    _stopwatch.start();
    final core = TimerCore(
      routine: routine,
      clock: () => _stopwatch.elapsedMilliseconds,
      settings: CueSettings(countdownSeconds: app.countdownSeconds),
    );
    _core = core;
    _handle(
      restore == null
          ? core.start()
          : core.restore(EngineCheckpoint.fromJson(restore)),
    );
    _saveSnapshot();
    _ticker = Timer.periodic(tickInterval, (_) => _handle(core.tick()));
  }

  static Future<Map<String, Object?>?> _readJson(String key) async {
    final raw = await FlutterForegroundTask.getData<String>(key: key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, Object?>();
    } catch (_) {
      return null;
    }
  }

  /// 이어하기용 진행 상태 저장 (구간이 바뀔 때, 조작할 때, 5초마다)
  void _saveSnapshot() {
    final core = _core;
    final store = _snapshots;
    if (core == null || store == null || _finished != null) return;
    _lastSnapshotAt = core.activeMs;
    final v = RunView.from(core);
    store.save(core.routine, core.checkpoint, RunLabels.progress(v)).catchError(
      (Object e) {
        debugPrint('RunTaskHandler: 진행 상태 저장 실패 $e');
      },
    );
  }

  void _handle(List<EngineEvent> events) {
    final core = _core;
    if (core == null) return;
    var changed = false;
    var saveNeeded = false;
    for (final e in events) {
      switch (e) {
        case CueDue(:final cue):
          _player?.play(cue);
        case SegmentStarted():
          changed = true;
          saveNeeded = true;
        case TrialCountable():
          // 실제 진행 60초가 된 순간 무료 운동 1회 차감 (docs/02 10.2절).
          // 운동 중에는 절대 막지 않는다. 잠금 판단은 다음 운동을 시작할 때 화면이 한다.
          _trial?.increment().catchError((Object e) {
            debugPrint('RunTaskHandler: 무료 횟수 저장 실패 $e');
            return 0;
          });
        case Finished():
          _player?.play(e.cue);
          _finished = e;
          changed = true;
      }
    }

    final now = _stopwatch.elapsedMilliseconds;
    if (changed || now - _lastViewAt >= viewInterval.inMilliseconds) {
      _lastViewAt = now;
      _sendView();
    }
    _updateNotification();

    if (_finished == null &&
        (saveNeeded ||
            core.activeMs - _lastSnapshotAt >=
                snapshotInterval.inMilliseconds)) {
      _saveSnapshot();
    }

    if (_finished != null && _ticker != null) {
      // 정상적으로 끝났으므로 이어하기 상태를 지운다
      _snapshots?.clear();
      _ticker!.cancel();
      _ticker = null;
      FlutterForegroundTask.sendDataToMain({
        'type': RunProtocol.finished,
        'totalActiveMs': _finished!.totalActiveMs,
        'stopped': _finished!.stopped,
        'routineName': core.routine.name,
        'view': RunView.from(core).toMap(),
      });
      _stopTimer = Timer(finishLinger, FlutterForegroundTask.stopService);
    }
  }

  void _sendView() {
    final core = _core;
    if (core == null) return;
    FlutterForegroundTask.sendDataToMain({
      'type': RunProtocol.view,
      'view': RunView.from(core).toMap(),
    });
  }

  void _updateNotification() {
    final core = _core;
    if (core == null || _finished != null) return;
    final v = RunView.from(core);
    final sec = v.segmentElapsedMs ~/ 1000;
    if (sec == _lastNotifySec && v.status == _lastNotifyStatus) return;
    _lastNotifySec = sec;
    final statusChanged = v.status != _lastNotifyStatus;
    _lastNotifyStatus = v.status;

    final paused = v.status == RunStatus.paused;
    final main = v.isRepWork
        ? '${RunLabels.segment(v.segmentType, isReps: v.isReps)} ${((v.completedReps ?? 0) + 1).clamp(1, v.targetReps!)}/${v.targetReps}회'
        : '${RunLabels.segment(v.segmentType, isReps: v.isReps)} ${RunLabels.clock(v.segmentRemainingMs)}';
    FlutterForegroundTask.updateService(
      notificationTitle: paused ? '일시정지 · ${v.routineName}' : v.routineName,
      notificationText: '$main · ${RunLabels.progress(v)}',
      notificationButtons: statusChanged
          ? [
              NotificationButton(
                id: paused ? RunProtocol.cmdResume : RunProtocol.cmdPause,
                text: paused ? '재개' : '일시정지',
              ),
              const NotificationButton(id: RunProtocol.cmdNext, text: '다음'),
            ]
          : null,
    );
  }

  void _command(String cmd, [Object? arg]) {
    final core = _core;
    if (core == null) return;
    switch (cmd) {
      case RunProtocol.cmdPause:
        _handle(core.pause());
      case RunProtocol.cmdResume:
        _handle(core.resume());
      case RunProtocol.cmdNext:
        _handle(core.next());
      case RunProtocol.cmdPrev:
        _handle(core.prev());
      case RunProtocol.cmdAddRest:
        _handle(core.addRest((arg as num?)?.toInt() ?? 10000));
      case RunProtocol.cmdStop:
        _handle(core.stop());
      case RunProtocol.cmdView:
        _sendView();
        return;
    }
    _saveSnapshot();
    _sendView();
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      final cmd = data['cmd'];
      if (cmd is String) _command(cmd, data['arg']);
    }
  }

  @override
  void onNotificationButtonPressed(String id) => _command(id);

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _ticker?.cancel();
    _stopTimer?.cancel();
    await _player?.dispose();
  }
}
