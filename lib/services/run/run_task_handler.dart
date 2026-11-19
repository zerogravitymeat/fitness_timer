import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../engine/timer_core.dart';
import '../../models/routine.dart';
import '../audio/cue_player.dart';
import 'run_labels.dart';
import 'run_protocol.dart';
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

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
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

    final player = CuePlayer();
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
    );
    _core = core;
    _handle(core.start());
    _ticker = Timer.periodic(tickInterval, (_) => _handle(core.tick()));
  }

  void _handle(List<EngineEvent> events) {
    final core = _core;
    if (core == null) return;
    var changed = false;
    for (final e in events) {
      switch (e) {
        case CueDue(:final cue):
          _player?.play(cue);
        case SegmentStarted():
          changed = true;
        case TrialCountable():
          // 무료 체험 차감은 결제 단계에서 연결한다 (docs/02 10.2절)
          break;
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

    if (_finished != null && _ticker != null) {
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
        break;
    }
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
