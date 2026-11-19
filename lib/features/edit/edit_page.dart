import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/routine.dart';
import '../common/routine_summary.dart';
import 'edit_rules.dart';

/// 편집 결과. [start]가 true면 저장 후 바로 시작.
class EditResult {
  const EditResult(this.routine, {required this.start});
  final Routine routine;
  final bool start;
}

/// S2 루틴 편집 (docs/03_화면_설계.md 4장). 기능 확인용 기본 UI.
class EditPage extends StatefulWidget {
  const EditPage({super.key, required this.initial, required this.isNew});

  final Routine initial;
  final bool isNew;

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  late Routine _r = widget.initial;
  late final _name = TextEditingController(text: widget.initial.name);
  late bool _customTempo = !_presetTempos.containsValue(widget.initial.tempo);

  static const _presetTempos = {
    '천천히': Tempo.slow,
    '보통': Tempo.normal,
    '빠르게': Tempo.fast,
  };

  bool get _dirty =>
      widget.isNew ||
      _name.text.trim() != widget.initial.name ||
      !_r.sameSettingsAs(widget.initial.copyWith(name: _r.name));

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _set(Routine r) {
    // 템포가 빨라져 "동작 + 숫자"를 못 쓰게 되면 숫자만으로 바꾼다
    if (r.cueStyle == CueStyle.actionAndNumbers &&
        !EditRules.actionCueAllowed(r.tempo)) {
      r = r.copyWith(cueStyle: CueStyle.numbersOnly);
    }
    setState(() => _r = r);
  }

  Future<void> _switchMode(EndCondition to) async {
    if (to == _r.endCondition) return;
    if (EditRules.switchingLosesSets(_r, to)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('세트 반복 설정이 사라집니다'),
          content: const Text('횟수 모드는 라운드를 "세트"로 쓰고, 바깥 세트 반복은 쓰지 않아요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('바꾸기'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    _set(EditRules.switchMode(_r, to));
  }

  void _finish({required bool start}) {
    final name = EditRules.validName(_name.text);
    if (name == null) return;
    Navigator.of(context)
        .pop(EditResult(_r.copyWith(name: name).normalized(), start: start));
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('변경 사항을 버릴까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('계속 편집'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('버리기'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final reps = r.isReps;
    final nameOk = EditRules.validName(_name.text) != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.isNew ? '새 루틴' : '루틴 편집')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            TextField(
              controller: _name,
              maxLength: RoutineLimits.maxNameLength,
              decoration: InputDecoration(
                labelText: '이름',
                errorText: nameOk ? null : '이름을 입력해 주세요',
              ),
            ),
            const SizedBox(height: 8),
            const _Label('운동 방식'),
            SegmentedButton<EndCondition>(
              segments: const [
                ButtonSegment(
                  value: EndCondition.time,
                  label: Text('시간'),
                  icon: Icon(Icons.timer_outlined),
                ),
                ButtonSegment(
                  value: EndCondition.reps,
                  label: Text('횟수'),
                  icon: Icon(Icons.repeat),
                ),
              ],
              selected: {r.endCondition},
              onSelectionChanged: (s) => _switchMode(s.first),
            ),
            const SizedBox(height: 12),
            _TimeStepper(
              label: '준비',
              ms: r.prepMs,
              min: 0,
              max: RoutineLimits.maxPrepMs,
              onChanged: (v) => _set(r.copyWith(prepMs: v)),
            ),
            if (!reps)
              _TimeStepper(
                label: '운동',
                ms: r.workMs,
                min: RoutineLimits.minWorkMs,
                max: RoutineLimits.maxWorkMs,
                onChanged: (v) => _set(r.copyWith(workMs: v)),
              )
            else ...[
              _IntStepper(
                label: '목표 횟수',
                value: r.targetReps,
                unit: '회',
                min: 1,
                max: RoutineLimits.maxReps,
                onChanged: (v) => _set(r.copyWith(targetReps: v)),
              ),
              _tempoEditor(r),
            ],
            _TimeStepper(
              label: reps ? '세트 간 휴식' : '휴식',
              ms: r.restMs,
              min: 0,
              max: RoutineLimits.maxRestMs,
              onChanged: (v) => _set(r.copyWith(restMs: v)),
            ),
            _IntStepper(
              label: reps ? '세트' : '라운드',
              value: r.rounds,
              min: 1,
              max: RoutineLimits.maxRounds,
              onChanged: (v) => _set(r.copyWith(rounds: v)),
            ),
            if (!reps) ...[
              _IntStepper(
                label: '세트',
                value: r.sets,
                min: 1,
                max: RoutineLimits.maxSets,
                onChanged: (v) => _set(r.copyWith(sets: v)),
              ),
              if (r.sets > 1)
                _TimeStepper(
                  label: '세트 간 휴식',
                  ms: r.setRestMs,
                  min: 0,
                  max: RoutineLimits.maxSetRestMs,
                  onChanged: (v) => _set(r.copyWith(setRestMs: v)),
                ),
            ],
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('더 보기'),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(reps ? '마지막 세트 휴식 건너뛰기' : '마지막 라운드 휴식 건너뛰기'),
                  value: r.skipLastRest,
                  onChanged: (v) => _set(r.copyWith(skipLastRest: v)),
                ),
                if (reps)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('음성 안내 방식'),
                    trailing: DropdownButton<CueStyle>(
                      value: r.cueStyle,
                      onChanged: (v) =>
                          v == null ? null : _set(r.copyWith(cueStyle: v)),
                      items: [
                        const DropdownMenuItem(
                          value: CueStyle.numbersOnly,
                          child: Text('숫자만'),
                        ),
                        DropdownMenuItem(
                          value: CueStyle.actionAndNumbers,
                          enabled: EditRules.actionCueAllowed(r.tempo),
                          child: Text(
                            EditRules.actionCueAllowed(r.tempo)
                                ? '동작 + 숫자'
                                : '동작 + 숫자 (1회 2.5초 이상)',
                          ),
                        ),
                        const DropdownMenuItem(
                          value: CueStyle.beepOnly,
                          child: Text('비프만'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '예상 시간 ${RoutineSummary.estimate(r)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: nameOk ? () => _finish(start: false) : null,
                        child: const Text('저장'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: nameOk ? () => _finish(start: true) : null,
                        child: const Text('저장 후 시작'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tempoEditor(Routine r) {
    final selected = _customTempo
        ? '직접'
        : _presetTempos.entries
                  .where((e) => e.value == r.tempo)
                  .firstOrNull
                  ?.key ??
              '직접';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('템포 (내려가기-멈춤-올라오기)'),
        Wrap(
          spacing: 8,
          children: [
            for (final e in _presetTempos.entries)
              ChoiceChip(
                label: Text('${e.key} ${e.value.label}'),
                selected: selected == e.key,
                onSelected: (_) {
                  _customTempo = false;
                  _set(r.copyWith(tempo: e.value));
                },
              ),
            ChoiceChip(
              label: const Text('직접'),
              selected: selected == '직접',
              onSelected: (_) => setState(() => _customTempo = true),
            ),
          ],
        ),
        if (selected == '직접') ...[
          _TempoStepper(
            label: '내려가기',
            ms: r.tempo.downMs,
            min: RoutineLimits.minTempoMs,
            onChanged: (v) => _set(
              r.copyWith(
                tempo: Tempo(
                  downMs: v,
                  holdMs: r.tempo.holdMs,
                  upMs: r.tempo.upMs,
                ),
              ),
            ),
          ),
          _TempoStepper(
            label: '멈춤',
            ms: r.tempo.holdMs,
            min: 0,
            onChanged: (v) => _set(
              r.copyWith(
                tempo: Tempo(
                  downMs: r.tempo.downMs,
                  holdMs: v,
                  upMs: r.tempo.upMs,
                ),
              ),
            ),
          ),
          _TempoStepper(
            label: '올라오기',
            ms: r.tempo.upMs,
            min: RoutineLimits.minTempoMs,
            onChanged: (v) => _set(
              r.copyWith(
                tempo: Tempo(
                  downMs: r.tempo.downMs,
                  holdMs: r.tempo.holdMs,
                  upMs: v,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

// ───────────────────────── 입력 위젯 ─────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 6),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}

String _fmtTime(int ms) {
  final s = ms ~/ 1000;
  if (s < 60) return '$s초';
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// `[−] 값 [+]`. 길게 누르면 값이 빠르게 바뀐다 (docs/03 4장).
const _valueStyle = TextStyle(
  fontSize: 18,
  fontFeatures: [FontFeature.tabularFigures()],
);

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.valueText,
    required this.canDown,
    required this.canUp,
    required this.onDown,
    required this.onUp,
    this.onTapValue,
  });

  final String label;
  final String valueText;
  final bool canDown;
  final bool canUp;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final VoidCallback? onTapValue;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
        _RepeatButton(
          icon: Icons.remove,
          enabled: canDown,
          onStep: onDown,
          tooltip: '$label 줄이기',
        ),
        SizedBox(
          width: 88,
          // 탭해서 바꿀 수 없는 값은 버튼이 아니라 글자로 (비활성 회색으로 보이지 않게)
          child: onTapValue == null
              ? Text(valueText, textAlign: TextAlign.center, style: _valueStyle)
              : TextButton(
                  onPressed: onTapValue,
                  child: Text(valueText, style: _valueStyle),
                ),
        ),
        _RepeatButton(
          icon: Icons.add,
          enabled: canUp,
          onStep: onUp,
          tooltip: '$label 늘리기',
        ),
      ],
    ),
  );
}

class _RepeatButton extends StatefulWidget {
  const _RepeatButton({
    required this.icon,
    required this.enabled,
    required this.onStep,
    required this.tooltip,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onStep;
  final String tooltip;

  @override
  State<_RepeatButton> createState() => _RepeatButtonState();
}

class _RepeatButtonState extends State<_RepeatButton> {
  Timer? _repeat;

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void didUpdateWidget(covariant _RepeatButton old) {
    super.didUpdateWidget(old);
    if (!widget.enabled) _stop(); // 최솟값·최댓값에 닿으면 반복 중지
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPressStart: widget.enabled
        ? (_) => _repeat = Timer.periodic(
            const Duration(milliseconds: 90),
            (_) => widget.onStep(),
          )
        : null,
    onLongPressEnd: (_) => _stop(),
    child: IconButton.filledTonal(
      tooltip: widget.tooltip,
      icon: Icon(widget.icon),
      onPressed: widget.enabled ? widget.onStep : null,
    ),
  );
}

class _TimeStepper extends StatelessWidget {
  const _TimeStepper({
    required this.label,
    required this.ms,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final int ms;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => _StepperRow(
    label: label,
    valueText: _fmtTime(ms),
    canDown: ms > min,
    canUp: ms < max,
    onDown: () =>
        onChanged(EditRules.stepTime(ms, up: false, min: min, max: max)),
    onUp: () => onChanged(EditRules.stepTime(ms, up: true, min: min, max: max)),
    onTapValue: () async {
      final v = await _pickTime(context, label, ms);
      if (v != null) onChanged(v.clamp(min, max));
    },
  );
}

class _IntStepper extends StatelessWidget {
  const _IntStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.unit = '',
  });
  final String label;
  final int value;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => _StepperRow(
    label: label,
    valueText: '$value$unit',
    canDown: value > min,
    canUp: value < max,
    onDown: () =>
        onChanged(EditRules.stepInt(value, up: false, min: min, max: max)),
    onUp: () =>
        onChanged(EditRules.stepInt(value, up: true, min: min, max: max)),
  );
}

class _TempoStepper extends StatelessWidget {
  const _TempoStepper({
    required this.label,
    required this.ms,
    required this.min,
    required this.onChanged,
  });
  final String label;
  final int ms;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => _StepperRow(
    label: label,
    valueText:
        '${ms % 1000 == 0 ? ms ~/ 1000 : (ms / 1000).toStringAsFixed(1)}초',
    canDown: ms > min,
    canUp: ms < RoutineLimits.maxTempoMs,
    onDown: () => onChanged(EditRules.stepTempo(ms, up: false, min: min)),
    onUp: () => onChanged(EditRules.stepTempo(ms, up: true, min: min)),
  );
}

/// 값을 탭하면 `분:초` 휠 선택기 (docs/03 4장)
Future<int?> _pickTime(BuildContext context, String label, int ms) {
  var m = (ms ~/ 1000) ~/ 60, s = (ms ~/ 1000) % 60;
  return showModalBottomSheet<int>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(label, style: Theme.of(c).textTheme.titleMedium),
          ),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 40,
                    scrollController: FixedExtentScrollController(
                      initialItem: m,
                    ),
                    onSelectedItemChanged: (v) => m = v,
                    children: [
                      for (var i = 0; i < 100; i++) Center(child: Text('$i분')),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 40,
                    scrollController: FixedExtentScrollController(
                      initialItem: s,
                    ),
                    onSelectedItemChanged: (v) => s = v,
                    children: [
                      for (var i = 0; i < 60; i++) Center(child: Text('$i초')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => Navigator.pop(c, (m * 60 + s) * 1000),
              child: const Text('확인'),
            ),
          ),
        ],
      ),
    ),
  );
}
