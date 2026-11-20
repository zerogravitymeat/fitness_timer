import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../engine/timer_core.dart';
import '../../l10n/l10n.dart';
import '../../models/app_settings.dart';
import '../../models/workout.dart';
import '../audio/sound_files.dart';
import 'run_protocol.dart';
import 'run_task_handler.dart';
import 'run_view.dart';

class RunResult {
  const RunResult({
    required this.routineName,
    required this.totalActiveMs,
    required this.stopped,
    required this.lastView,
  });
  final String routineName;
  final int totalActiveMs;
  final bool stopped;
  final RunView lastView;
}

/// 화면 쪽에서 서비스를 시작·조작하고 진행 상태를 받는다.
class RunClient extends ChangeNotifier {
  /// 알림 문구. 앱에서 언어를 정했으면 그 언어, 아니면 기기 언어.
  AppLocalizations _l([String? language]) => l10nFor(
    language == null
        ? WidgetsBinding.instance.platformDispatcher.locale
        : Locale(language),
  );

  RunClient._();
  static final instance = RunClient._();

  RunView? _view;
  final _sinceView = Stopwatch();
  RunResult? _result;
  bool _initialized = false;

  RunResult? get result => _result;
  bool get hasView => _view != null;

  /// 마지막으로 받은 상태를 지금 시각까지 보간한 값
  RunView? get view => _view?.advancedBy(_sinceView.elapsedMilliseconds);

  void init() {
    if (_initialized) return;
    _initialized = true;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'run',
        channelName: _l().notificationChannelName,
        channelDescription: _l().notificationChannelDescription,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true, // 화면이 꺼져도 CPU가 잠들지 않게 (docs/05 6.1절)
        allowWifiLock: false,
      ),
    );
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  /// 이미 진행 중인 서비스가 있으면 최신 상태를 요청한다 (앱을 다시 열었을 때)
  Future<bool> reattach() async {
    if (!await isRunning) return false;
    send(RunProtocol.cmdView);
    return true;
  }

  /// [restore]가 있으면 저장된 위치에서 일시정지 상태로 이어서 시작한다.
  Future<bool> start(
    Workout workout, {
    required AppSettings settings,
    required String dataDir,
    EngineCheckpoint? restore,
  }) async {
    final perm = await FlutterForegroundTask.checkNotificationPermission();
    if (perm != NotificationPermission.granted) {
      // 거부해도 타이머는 시작한다 (docs/03 D2)
      await FlutterForegroundTask.requestNotificationPermission();
    }
    _view = null;
    _result = null;
    await FlutterForegroundTask.saveData(
      key: RunProtocol.soundDirKey,
      value: await SoundFiles.prepare(),
    );
    await FlutterForegroundTask.saveData(
      key: RunProtocol.settingsKey,
      value: jsonEncode(settings.toJson()),
    );
    await FlutterForegroundTask.saveData(
      key: RunProtocol.dataDirKey,
      value: dataDir,
    );
    await FlutterForegroundTask.saveData(
      key: RunProtocol.restoreKey,
      value: restore == null ? '' : jsonEncode(restore.toJson()),
    );
    await FlutterForegroundTask.saveData(
      key: RunProtocol.workoutKey,
      value: jsonEncode(workout.toJson()),
    );
    // 이전 운동의 서비스(완료음 재생 중 등)가 남아 있으면 완전히 내려간 뒤 시작한다
    if (await isRunning) {
      await FlutterForegroundTask.stopService();
      for (var i = 0; i < 20 && await isRunning; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    final r = await FlutterForegroundTask.startService(
      serviceId: 100,
      serviceTypes: [ForegroundServiceTypes.specialUse],
      notificationTitle: workout.name,
      notificationText: _l(settings.language).notificationStarting,
      notificationButtons: [
        NotificationButton(
          id: RunProtocol.cmdPause,
          text: _l(settings.language).pause,
        ),
        NotificationButton(
          id: RunProtocol.cmdNext,
          text: _l(settings.language).next,
        ),
      ],
      callback: runServiceEntryPoint,
    );
    notifyListeners();
    return r is ServiceRequestSuccess;
  }

  /// 시작에 실패한 것으로 판단했을 때 서비스를 내린다
  Future<void> cancel() async {
    if (await isRunning) await FlutterForegroundTask.stopService();
  }

  void send(String cmd, [Object? arg]) =>
      FlutterForegroundTask.sendDataToTask({'cmd': cmd, 'arg': arg});

  void clearResult() {
    _result = null;
    _view = null;
    notifyListeners();
  }

  void _onData(Object data) {
    if (data is! Map) return;
    switch (data['type']) {
      case RunProtocol.view:
        _view = RunView.fromMap(data['view'] as Map);
        _sinceView
          ..reset()
          ..start();
      case RunProtocol.finished:
        _view = RunView.fromMap(data['view'] as Map);
        _result = RunResult(
          routineName: data['routineName'] as String? ?? '',
          totalActiveMs: (data['totalActiveMs'] as num?)?.toInt() ?? 0,
          stopped: data['stopped'] as bool? ?? false,
          lastView: _view!,
        );
    }
    notifyListeners();
  }
}
