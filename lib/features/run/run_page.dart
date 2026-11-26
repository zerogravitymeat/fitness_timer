import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/app_services.dart';
import '../../design/glass.dart';
import '../../design/tokens.dart';
import '../../engine/segment.dart';
import '../../models/entitlement.dart';
import '../../models/routine.dart';
import '../../engine/timer_core.dart';
import '../../services/run/run_client.dart';
import '../paywall/paywall_page.dart';
import '../../services/run/run_labels.dart';
import '../../services/run/run_protocol.dart';
import '../../services/run/run_view.dart';
import '../../l10n/l10n.dart';

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

  bool _resultShown = false;

  void _onClient() {
    final result = _client.result;
    if (result != null && mounted && !_resultShown) {
      _resultShown = true;
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
        title: Text(context.l10n.stopConfirmTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(context.l10n.keepGoing),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(context.l10n.stopAction),
          ),
        ],
      ),
    );
    if (ok == true) _client.send(RunProtocol.cmdStop);
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
              Text(
                context.l10n.timerStartFailed,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  // 뒤늦게 시작된 서비스가 화면 없이 혼자 소리를 내지 않게 내린다
                  _client.cancel();
                  Navigator.of(context).pop();
                },
                child: Text(context.l10n.goHome),
              ),
            ],
          ),
        ),
      );
    }
    final paused = v.status == RunStatus.paused;
    final isRest =
        v.segmentType == SegmentType.rest ||
        v.segmentType == SegmentType.setRest ||
        v.segmentType == SegmentType.courseRest;
    final segName = RunLabels.segment(
      context.l10n,
      v.segmentType,
      isReps: v.isReps,
    );
    final colors = PhaseColors.of(
      v.segmentType,
      isReps: v.isReps,
      paused: paused,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmStop(); // 뒤로 가기 → 일시정지 + 확인 (docs/03 5.4절)
      },
      child: Scaffold(
        // 어두운 바탕 + 구간 색 빛 번짐, 구간이 바뀌면 600ms 동안 서서히 (docs/04 2.3절)
        body: PhaseBackground(
          colors: colors,
          child: SafeArea(
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
                        glow: colors.c1,
                      )
                    : _portrait(
                        v,
                        c,
                        paused: paused,
                        isRest: isRest,
                        segName: segName,
                        glow: colors.c1,
                      ),
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
    required Color glow,
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
            Expanded(flex: 14, child: _pauseButton(paused, glow: glow)),
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
    required Color glow,
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
              Expanded(
                flex: 2,
                child: _pauseButton(paused, height: null, glow: glow),
              ),
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

  /// 루틴: 루틴 이름. 코스: 코스 이름 아래에 "2/4 스쿼트" (docs/03 5.6절)
  Widget _title(RunView v) {
    final style = TextStyle(
      color: Colors.white.withValues(alpha: 0.88),
      fontSize: 17,
      fontWeight: FontWeight.w500,
    );
    if (!v.isCourse) {
      return Text(v.routineName, style: style, overflow: TextOverflow.ellipsis);
    }
    return Column(
      children: [
        Text(
          v.workoutName,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.66),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          v.segmentType == SegmentType.courseRest
              ? context.l10n.nextCoursePosition(RunLabels.coursePosition(v))
              : RunLabels.coursePosition(v),
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(fontFeatures: tabularFigures),
        ),
      ],
    );
  }

  Widget _info(RunView v, {required bool paused, required String segName}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassPill(child: Text(paused ? context.l10n.pause : segName)),
        const SizedBox(height: 12),
        if (v.isRepWork) _RepCounter(v: v) else _TimeDisplay(v: v),
        const SizedBox(height: 20),
        if (v.isRepWork) _TempoBar(v: v) else _ProgressBar(v: v),
        const SizedBox(height: 24),
        // 작은 글자는 반드시 유리 패널 안에 둔다 (밝은 빛 위 대비, docs/04 6장)
        GlassPanel(
          blur: true,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                RunLabels.progress(context.l10n, v),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      RunLabels.next(context.l10n, v),
                      style: _subStyle,
                    ),
                  ),
                  Text(
                    context.l10n.totalRemaining(
                      RunLabels.clock(v.remainingTotalMs),
                    ),
                    style: _subStyle,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static final _subStyle = TextStyle(
    color: Colors.white.withValues(alpha: 0.86),
    fontSize: 14,
    fontFeatures: tabularFigures,
  );

  Widget _addRestButton() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _client.send(RunProtocol.cmdAddRest, 10000),
        child: GlassPill(
          child: Text(
            context.l10n.plusTenSeconds,
            style: const TextStyle(fontSize: 16, letterSpacing: 0),
          ),
        ),
      ),
    ),
  );

  Widget _prevButton({double? height = 76}) => GlassButton(
    height: height,
    icon: Icons.skip_previous_rounded,
    label: context.l10n.previous,
    onPressed: () => _client.send(RunProtocol.cmdPrev),
  );

  Widget _pauseButton(
    bool paused, {
    double? height = 76,
    required Color glow,
  }) => GlassButton(
    height: height,
    primary: true,
    glowColor: glow,
    icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
    label: paused ? context.l10n.resume : context.l10n.pause,
    onPressed: () =>
        _client.send(paused ? RunProtocol.cmdResume : RunProtocol.cmdPause),
  );

  Widget _nextButton(RunView v, {double? height = 76}) => GlassButton(
    height: height,
    icon: v.isRepWork ? Icons.check_rounded : Icons.skip_next_rounded,
    label: v.isRepWork ? context.l10n.setDone : context.l10n.next,
    onPressed: () => _client.send(RunProtocol.cmdNext),
  );

  /// 실수로 끝나지 않게 일시정지했을 때만 보인다 (docs/03 5.4절)
  Widget _stopButton() => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextButton(
      style: TextButton.styleFrom(foregroundColor: Colors.white),
      onPressed: _confirmStop,
      child: Text(
        context.l10n.endWorkout,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

/// 큰 숫자: 고정폭 + 옅은 그림자 (밝은 빛 위에서도 또렷하게, docs/04 5장)
const _bigNumberStyle = TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.w600,
  letterSpacing: -4,
  height: 1.05,
  fontFeatures: tabularFigures,
  shadows: [
    Shadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 4)),
  ],
);

class _TimeDisplay extends StatelessWidget {
  const _TimeDisplay({required this.v});
  final RunView v;

  @override
  Widget build(BuildContext context) => FittedBox(
    child: Text(
      RunLabels.clock(v.segmentRemainingMs),
      style: _bigNumberStyle.copyWith(fontSize: 132),
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
          Text('$current', style: _bigNumberStyle.copyWith(fontSize: 168)),
          Text(
            ' / ${v.targetReps}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 40,
              fontWeight: FontWeight.w500,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

/// 구간 진행 바: 흰색 채움 + 반투명 트랙
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.v});
  final RunView v;

  @override
  Widget build(BuildContext context) {
    final f = v.segmentDurationMs == 0
        ? 0.0
        : (v.segmentElapsedMs / v.segmentDurationMs).clamp(0.0, 1.0);
    return Container(
      height: 12,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: f,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              colors: [Colors.white, Colors.white.withValues(alpha: 0.75)],
            ),
          ),
        ),
      ),
    );
  }
}

/// 1회 안에서 지금 위치. 회차마다 처음부터 다시 찬다 (docs/03 5.2절)
class _TempoBar extends StatelessWidget {
  const _TempoBar({required this.v});
  final RunView v;

  @override
  Widget build(BuildContext context) {
    final repMs = v.repMs!;
    final f = ((v.repElapsedMs ?? 0) / repMs).clamp(0.0, 1.0);
    return Column(
      children: [
        Container(
          height: 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withValues(alpha: 0.14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: f,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.tempoPerRep(Tempo(repMs).seconds),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.86),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

/// 결과 화면 (docs/03 6장)
class ResultPage extends StatefulWidget {
  const ResultPage({super.key, required this.result});
  final RunResult result;

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  @override
  void initState() {
    super.initState();
    // 서비스가 차감한 무료 운동 횟수를 다시 읽는다
    AppServices.entitlement.refreshTrial();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final v = result.lastView;
    final done = !result.stopped;
    final content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            // 완료: 체크, 중단: 깃발 (유리 원)
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: GlassLevel.strong.fill),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: GlassLevel.strong.border,
                  ),
                ),
              ),
              child: Icon(
                done ? Icons.check_rounded : Icons.flag_rounded,
                size: 52,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              done ? context.l10n.workoutComplete : context.l10n.workoutStopped,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              result.routineName,
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.86),
              ),
            ),
            const SizedBox(height: 28),
            GlassPanel(
              blur: true,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                children: [
                  _StatRow(
                    label: context.l10n.totalTime,
                    value: RunLabels.elapsed(result.totalActiveMs),
                  ),
                  if (done) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    v.isCourse
                        ? _StatRow(
                            label: context.l10n.routinesDone,
                            value: '${v.partCount} / ${v.partCount}',
                          )
                        : _StatRow(
                            label: v.isReps
                                ? context.l10n.setsDone
                                : context.l10n.progress,
                            value: v.isReps
                                ? '${v.rounds} / ${v.rounds}'
                                : RunLabels.progress(context.l10n, v),
                          ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            // 체험 안내 (docs/02 10.4절, docs/03 6장)
            ListenableBuilder(
              listenable: AppServices.entitlement,
              builder: (context, _) => _TrialNotice(
                notice: AppServices.entitlement.noticeAfterRun(),
                remaining: AppServices.entitlement.value.freeRemaining,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: Colors.white.withValues(alpha: 0.92),
                foregroundColor: const Color(0xFF14161F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () {
                RunClient.instance.clearResult();
                Navigator.of(context).pop();
              },
              child: Text(context.l10n.goHome),
            ),
          ],
        ),
      ),
    );
    // 끝까지 했으면 Aurora 배경 (docs/04 2.2절 완료)
    return Scaffold(body: done ? AuroraBackground(child: content) : content);
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFeatures: tabularFigures,
        ),
      ),
    ],
  );
}

class _TrialNotice extends StatelessWidget {
  const _TrialNotice({required this.notice, required this.remaining});
  final TrialNotice? notice;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    switch (notice) {
      case null:
        return const SizedBox.shrink();
      case TrialNotice.remaining:
        return TextButton(
          onPressed: () => PaywallPage.open(context),
          child: Text(context.l10n.freeRemainingResult(remaining)),
        );
      case TrialNotice.ended:
        return GlassPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.trialUsedUp,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(context.l10n.trialUsedUpBody),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => PaywallPage.open(context),
                child: Text(context.l10n.viewFullVersion),
              ),
            ],
          ),
        );
    }
  }
}
