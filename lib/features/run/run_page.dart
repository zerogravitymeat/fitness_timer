import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/app_services.dart';
import '../../engine/segment.dart';
import '../../engine/tempo_clock.dart';
import '../../engine/timer_core.dart';
import '../../services/run/run_client.dart';
import '../../services/run/run_labels.dart';
import '../../services/run/run_protocol.dart';
import '../../services/run/run_view.dart';

/// 기본 진행 화면 (docs/03_화면_설계.md 5장). 기능 확인용으로 단순하게 만든다.
class RunPage extends StatefulWidget {
  const RunPage({super.key});

  @override
  State<RunPage> createState() => _RunPageState();
}

class _RunPageState extends State<RunPage> with SingleTickerProviderStateMixin {
  final _client = RunClient.instance;
  late final Ticker _ticker;
  final _waiting = Stopwatch()..start();

  /// 이 시간 안에 서비스 상태가 오지 않으면 시작 실패로 본다
  static const _startTimeout = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    // 진행 화면이 열려 있는 동안 화면 켜 둠 (docs/05 6.4절, 설정에서 끌 수 있음)
    if (AppServices.settings.value.keepScreenOn) WakelockPlus.enable();
    _client.addListener(_onClient);
    // 서비스가 0.5초마다 보내는 상태를 화면에서 매 프레임 보간해 그린다
    _ticker = createTicker((_) => setState(() {}))..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _client.removeListener(_onClient);
    WakelockPlus.disable();
    super.dispose();
  }

  void _onClient() {
    final result = _client.result;
    if (result != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResultPage(result: result)),
      );
    }
  }

  Future<void> _confirmStop() async {
    final v = _client.view;
    if (v?.status == RunStatus.running) _client.send(RunProtocol.cmdPause);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('운동을 끝낼까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('계속하기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('끝내기'),
          ),
        ],
      ),
    );
    if (ok == true) _client.send(RunProtocol.cmdStop);
  }

  Color _color(SegmentType? t, RunStatus s) {
    if (s == RunStatus.paused) return const Color(0xFF4B5468);
    return switch (t) {
      SegmentType.prep => const Color(0xFFB7832F),
      SegmentType.work => const Color(0xFFC2434F),
      SegmentType.rest => const Color(0xFF178A72),
      SegmentType.setRest => const Color(0xFF4A57C7),
      null => const Color(0xFF6B4BC7),
    };
  }

  @override
  Widget build(BuildContext context) {
    final v = _client.view;
    if (v == null) {
      if (_waiting.elapsed < _startTimeout) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('타이머를 시작하지 못했어요', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('홈으로'),
              ),
            ],
          ),
        ),
      );
    }
    final paused = v.status == RunStatus.paused;
    final isRest =
        v.segmentType == SegmentType.rest ||
        v.segmentType == SegmentType.setRest;
    final segName = RunLabels.segment(v.segmentType, isReps: v.isReps);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmStop(); // 뒤로 가기 → 일시정지 + 확인 (docs/03 5.4절)
      },
      child: Scaffold(
        backgroundColor: _color(v.segmentType, v.status),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: LayoutBuilder(
              builder: (context, c) => c.maxWidth > c.maxHeight
                  ? _landscape(
                      v,
                      c,
                      paused: paused,
                      isRest: isRest,
                      segName: segName,
                    )
                  : _portrait(
                      v,
                      c,
                      paused: paused,
                      isRest: isRest,
                      segName: segName,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// 세로: 위에 정보, 아래에 버튼 한 줄 (docs/03 5.1~5.2절)
  Widget _portrait(
    RunView v,
    BoxConstraints c, {
    required bool paused,
    required bool isRest,
    required String segName,
  }) {
    return Column(
      children: [
        _title(v),
        Expanded(
          child: _fit(c.maxWidth, _info(v, paused: paused, segName: segName)),
        ),
        if (isRest) _addRestButton(),
        Row(
          children: [
            Expanded(flex: 10, child: _prevButton()),
            const SizedBox(width: 14),
            Expanded(flex: 14, child: _pauseButton(paused)),
            const SizedBox(width: 14),
            Expanded(flex: 10, child: _nextButton(v)),
          ],
        ),
        if (paused) _stopButton(),
      ],
    );
  }

  /// 가로: 왼쪽 70%에 정보, 오른쪽에 버튼 세로 배치 (docs/03 5.3절)
  Widget _landscape(
    RunView v,
    BoxConstraints c, {
    required bool paused,
    required bool isRest,
    required String segName,
  }) {
    final infoWidth = c.maxWidth * 0.68;
    return Row(
      children: [
        SizedBox(
          width: infoWidth,
          child: Column(
            children: [
              _title(v),
              Expanded(
                child: _fit(
                  infoWidth,
                  _info(v, paused: paused, segName: segName),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            children: [
              if (isRest) _addRestButton(),
              Expanded(child: _prevButton(height: null)),
              const SizedBox(height: 10),
              Expanded(flex: 2, child: _pauseButton(paused, height: null)),
              const SizedBox(height: 10),
              Expanded(child: _nextButton(v, height: null)),
              if (paused) _stopButton(),
            ],
          ),
        ),
      ],
    );
  }

  /// 공간이 부족하면 정보 영역 전체를 비율대로 줄인다 (넘침 방지)
  Widget _fit(double width, Widget child) => Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(width: width, child: child),
    ),
  );

  Widget _title(RunView v) => Text(
    v.routineName,
    style: const TextStyle(color: Colors.white70, fontSize: 17),
  );

  Widget _info(RunView v, {required bool paused, required String segName}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          paused ? '일시정지' : (v.isRepWork ? _phaseLabel(v.tempoPhase) : segName),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (v.isRepWork) _RepCounter(v: v) else _TimeDisplay(v: v),
        const SizedBox(height: 20),
        if (v.isRepWork) _TempoBar(v: v) else _ProgressBar(v: v),
        const SizedBox(height: 24),
        Text(
          '${v.isRepWork ? '$segName · ' : ''}${RunLabels.progress(v)}',
          style: const TextStyle(color: Colors.white, fontSize: 17),
        ),
        const SizedBox(height: 4),
        Text(
          RunLabels.next(v),
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        Text(
          '전체 남은 시간 ${RunLabels.clock(v.remainingTotalMs)}',
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
      ],
    );
  }

  Widget _addRestButton() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54),
        minimumSize: const Size(140, 48),
      ),
      onPressed: () => _client.send(RunProtocol.cmdAddRest, 10000),
      child: const Text('+10초', style: TextStyle(fontSize: 16)),
    ),
  );

  Widget _prevButton({double? height = 76}) => _BigButton(
    height: height,
    icon: Icons.skip_previous,
    label: '이전',
    onTap: () => _client.send(RunProtocol.cmdPrev),
  );

  Widget _pauseButton(bool paused, {double? height = 76}) => _BigButton(
    height: height,
    primary: true,
    icon: paused ? Icons.play_arrow : Icons.pause,
    label: paused ? '재개' : '일시정지',
    onTap: () =>
        _client.send(paused ? RunProtocol.cmdResume : RunProtocol.cmdPause),
  );

  Widget _nextButton(RunView v, {double? height = 76}) => _BigButton(
    height: height,
    icon: v.isRepWork ? Icons.check : Icons.skip_next,
    label: v.isRepWork ? '세트 완료' : '다음',
    onTap: () => _client.send(RunProtocol.cmdNext),
  );

  /// 실수로 끝나지 않게 일시정지했을 때만 보인다 (docs/03 5.4절)
  Widget _stopButton() => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextButton(
      style: TextButton.styleFrom(foregroundColor: Colors.white),
      onPressed: _confirmStop,
      child: const Text('운동 끝내기', style: TextStyle(fontSize: 16)),
    ),
  );

  String _phaseLabel(TempoPhase? p) => switch (p) {
    TempoPhase.down => '내려가기',
    TempoPhase.hold => '멈춤',
    TempoPhase.up => '올라오기',
    null => '',
  };
}

class _TimeDisplay extends StatelessWidget {
  const _TimeDisplay({required this.v});
  final RunView v;

  @override
  Widget build(BuildContext context) => FittedBox(
    child: Text(
      RunLabels.clock(v.segmentRemainingMs),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 140,
        fontWeight: FontWeight.w600,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    ),
  );
}

class _RepCounter extends StatelessWidget {
  const _RepCounter({required this.v});
  final RunView v;

  @override
  Widget build(BuildContext context) {
    final current = ((v.completedReps ?? 0) + 1).clamp(1, v.targetReps!);
    return FittedBox(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$current',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 168,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            ' / ${v.targetReps}',
            style: const TextStyle(color: Colors.white70, fontSize: 40),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.v});
  final RunView v;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: LinearProgressIndicator(
      minHeight: 12,
      value: v.segmentDurationMs == 0
          ? 0
          : v.segmentElapsedMs / v.segmentDurationMs,
      color: Colors.white,
      backgroundColor: Colors.white24,
    ),
  );
}

/// 1회 동작 안에서 지금 위치 (docs/03 5.2절)
class _TempoBar extends StatelessWidget {
  const _TempoBar({required this.v});
  final RunView v;

  @override
  Widget build(BuildContext context) {
    final down = v.tempoDownMs!, hold = v.tempoHoldMs!, up = v.tempoUpMs!;
    final total = down + hold + up;
    final pos = (v.repElapsedMs ?? 0) / total;
    Widget part(int ms, String label) => Expanded(
      flex: ms,
      child: Column(
        children: [
          Container(
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, c) => Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              part(down, '내려가기 ${RunLabels.duration(down)}'),
              if (hold > 0) part(hold, '멈춤'),
              part(up, '올라오기 ${RunLabels.duration(up)}'),
            ],
          ),
          Positioned(
            left: (c.maxWidth * pos).clamp(0, c.maxWidth - 6),
            top: -6,
            child: Container(
              width: 6,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.height = 76,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  /// null이면 부모가 준 높이를 채운다 (가로 배치). 기본 76dp (docs/03 2.2절: 72dp 이상)
  final double? height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: primary ? Colors.white : Colors.white24,
        foregroundColor: primary ? Colors.black87 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        padding: EdgeInsets.zero,
      ),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 26),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    ),
  );
}

/// 결과 화면 (docs/03 6장)
class ResultPage extends StatelessWidget {
  const ResultPage({super.key, required this.result});
  final RunResult result;

  @override
  Widget build(BuildContext context) {
    final v = result.lastView;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Text(
                result.stopped ? '운동 종료' : '운동 완료!',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(result.routineName, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
              Text(
                '총 시간  ${RunLabels.elapsed(result.totalActiveMs)}',
                style: const TextStyle(fontSize: 20),
              ),
              if (!result.stopped)
                Text(
                  v.isReps
                      ? '완료한 세트  ${v.rounds} / ${v.rounds}'
                      : RunLabels.progress(v),
                  style: const TextStyle(fontSize: 20),
                ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: () {
                  RunClient.instance.clearResult();
                  Navigator.of(context).pop();
                },
                child: const Text('홈으로'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
