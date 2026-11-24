import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../design/glass.dart';
import '../../design/tokens.dart';
import '../../models/exercise_names.dart';
import '../../models/routine.dart';
import '../common/routine_summary.dart';
import '../../l10n/l10n.dart';
import 'edit_rules.dart';
import 'name_search.dart';

/// 편집 결과. [start]가 true면 저장 후 바로 시작.
class EditResult {
  const EditResult(this.routine, {required this.start});
  final Routine routine;
  final bool start;
}

/// S2 루틴 편집 (docs/03_화면_설계.md 4장). 기능 확인용 기본 UI.
class EditPage extends StatefulWidget {
  const EditPage({
    super.key,
    required this.initial,
    required this.isNew,
    this.myRoutines = const [],
  });

  final Routine initial;
  final bool isNew;

  /// 이름 자동완성에 함께 보여줄 내 루틴. 고르면 그 설정을 가져온다.
  final List<Routine> myRoutines;

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  late Routine _r = widget.initial;
  late final _name = TextEditingController(text: widget.initial.name);
  final _nameFocus = FocusNode();

  /// 직전에 이름 추천으로 자동으로 채운 설정. 다른 추천을 고르면 다시 바꿔도 된다.
  Routine? _autoFilled;
  late bool _customTempo = !_presetTempos.contains(widget.initial.tempo);

  static const _presetTempos = [Tempo.slow, Tempo.normal, Tempo.fast];

  String _tempoName(Tempo t) => switch (t) {
    Tempo.slow => context.l10n.tempoSlow,
    Tempo.normal => context.l10n.tempoNormal,
    _ => context.l10n.tempoFast,
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
    _nameFocus.dispose();
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
          title: Text(context.l10n.switchToRepsTitle),
          content: Text(context.l10n.switchToRepsBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(context.l10n.switchAction),
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
    // 자동 채우기 안내가 홈 화면까지 따라가지 않게
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context)
        .pop(EditResult(_r.copyWith(name: name).normalized(), start: start));
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(context.l10n.discardChangesTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(context.l10n.keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(context.l10n.discard),
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
        final messenger = ScaffoldMessenger.of(context);
        if (await _confirmDiscard()) {
          messenger.hideCurrentSnackBar();
          nav.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isNew ? context.l10n.newRoutine : context.l10n.editRoutine,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _card([
              _nameField(nameOk),
              const SizedBox(height: 8),
              _Label(context.l10n.workoutMode),
              SegmentedButton<EndCondition>(
                segments: [
                  ButtonSegment(
                    value: EndCondition.time,
                    label: Text(context.l10n.modeTime),
                    icon: const Icon(Icons.timer_outlined),
                  ),
                  ButtonSegment(
                    value: EndCondition.reps,
                    label: Text(context.l10n.modeReps),
                    icon: const Icon(Icons.repeat),
                  ),
                ],
                selected: {r.endCondition},
                onSelectionChanged: (s) => _switchMode(s.first),
              ),
              const SizedBox(height: 8),
            ]),
            _card([
              _TimeStepper(
                label: context.l10n.segmentPrep,
                ms: r.prepMs,
                min: 0,
                max: RoutineLimits.maxPrepMs,
                onChanged: (v) => _set(r.copyWith(prepMs: v)),
              ),
              if (!reps)
                _TimeStepper(
                  label: context.l10n.segmentWork,
                  ms: r.workMs,
                  min: RoutineLimits.minWorkMs,
                  max: RoutineLimits.maxWorkMs,
                  onChanged: (v) => _set(r.copyWith(workMs: v)),
                )
              else ...[
                _IntStepper(
                  label: context.l10n.targetReps,
                  value: r.targetReps,
                  format: context.l10n.repsCount,
                  min: 1,
                  max: RoutineLimits.maxReps,
                  onChanged: (v) => _set(r.copyWith(targetReps: v)),
                ),
                _tempoEditor(r),
              ],
              _TimeStepper(
                label: reps
                    ? context.l10n.segmentSetRest
                    : context.l10n.segmentRest,
                ms: r.restMs,
                min: 0,
                max: RoutineLimits.maxRestMs,
                onChanged: (v) => _set(r.copyWith(restMs: v)),
              ),
              _IntStepper(
                label: reps ? context.l10n.sets : context.l10n.rounds,
                value: r.rounds,
                min: 1,
                max: RoutineLimits.maxRounds,
                onChanged: (v) => _set(r.copyWith(rounds: v)),
              ),
              if (!reps) ...[
                _IntStepper(
                  label: context.l10n.sets,
                  value: r.sets,
                  min: 1,
                  max: RoutineLimits.maxSets,
                  onChanged: (v) => _set(r.copyWith(sets: v)),
                ),
                if (r.sets > 1)
                  _TimeStepper(
                    label: context.l10n.segmentSetRest,
                    ms: r.setRestMs,
                    min: 0,
                    max: RoutineLimits.maxSetRestMs,
                    onChanged: (v) => _set(r.copyWith(setRestMs: v)),
                  ),
              ],
            ]),
            _card([
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(context.l10n.moreOptions),
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      reps
                          ? context.l10n.skipLastSetRest
                          : context.l10n.skipLastRoundRest,
                    ),
                    value: r.skipLastRest,
                    onChanged: (v) => _set(r.copyWith(skipLastRest: v)),
                  ),
                  if (reps)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.cueStyleTitle),
                      trailing: DropdownButton<CueStyle>(
                        value: r.cueStyle,
                        onChanged: (v) =>
                            v == null ? null : _set(r.copyWith(cueStyle: v)),
                        items: [
                          DropdownMenuItem(
                            value: CueStyle.numbersOnly,
                            child: Text(context.l10n.cueNumbersOnly),
                          ),
                          DropdownMenuItem(
                            value: CueStyle.actionAndNumbers,
                            enabled: EditRules.actionCueAllowed(r.tempo),
                            child: Text(
                              EditRules.actionCueAllowed(r.tempo)
                                  ? context.l10n.cueActionAndNumbers
                                  : context.l10n.cueActionAndNumbersDisabled,
                            ),
                          ),
                          DropdownMenuItem(
                            value: CueStyle.beepOnly,
                            child: Text(context.l10n.cueBeepOnly),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ]),
          ],
        ),
        // 하단 고정: 예상 시간 + 저장 (유리 바)
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.bgBase.withValues(alpha: 0.72),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.estimatedTime(
                      RoutineSummary.estimate(context.l10n, r),
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: nameOk
                              ? () => _finish(start: false)
                              : null,
                          child: Text(context.l10n.save),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: nameOk ? () => _finish(start: true) : null,
                          child: Text(context.l10n.saveAndStart),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 추천에서 이름을 고르면 새 루틴의 설정을 채운다.
  /// 내 루틴이면 그 설정을, 운동 목록이면 운동별 기본값을 쓴다.
  void _onPickName(String name) {
    final ok = EditRules.canAutoFill(
      isNew: widget.isNew,
      current: _r,
      initial: widget.initial,
      lastAutoFilled: _autoFilled,
    );
    if (!ok) return;
    final mine = widget.myRoutines.where((r) => r.name == name).firstOrNull;
    final defaults = ExerciseNames.defaultsOf(name);
    final Routine next;
    final String message;
    if (mine != null) {
      next = mine.copyWith(id: _r.id, name: _r.name, isPreset: false);
      message = context.l10n.autoFillCopied(name);
    } else if (defaults != null) {
      next = defaults.applyTo(_r);
      message = context.l10n.autoFillDefaults(name);
    } else {
      return;
    }
    if (next.sameSettingsAs(_r)) return;

    final before = _r, beforeCustom = _customTempo, beforeAuto = _autoFilled;
    setState(() {
      _r = next;
      _autoFilled = next;
      _customTempo = !_presetTempos.contains(next.tempo);
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          // 버튼이 있는 SnackBar는 기본으로 사라지지 않으므로
          // 직접 시간이 지나면 닫히게 한다
          persist: false,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: context.l10n.undo,
            onPressed: () => setState(() {
              _r = before;
              _customTempo = beforeCustom;
              _autoFilled = beforeAuto;
            }),
          ),
        ),
      );
  }

  /// 이름 입력칸. 치는 동안 운동 이름과 내 루틴 이름을 추천한다.
  Widget _nameField(bool nameOk) {
    final myNames = [for (final r in widget.myRoutines) r.name];
    final mine = myNames.toSet();
    final common = ExerciseNames.namesFor(
      Localizations.localeOf(context).languageCode,
    );
    return RawAutocomplete<String>(
      textEditingController: _name,
      focusNode: _nameFocus,
      onSelected: _onPickName,
      optionsBuilder: (v) =>
          NameSearch.search(v.text, mine: myNames, common: common),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
          TextField(
            controller: controller,
            focusNode: focusNode,
            maxLength: RoutineLimits.maxNameLength,
            onSubmitted: (_) => onSubmitted(),
            decoration: InputDecoration(
              labelText: context.l10n.name,
              errorText: nameOk ? null : context.l10n.nameRequired,
            ),
          ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Padding(
          // 글자 수 표시 줄 위로 붙인다
          padding: const EdgeInsets.only(top: 4),
          child: Material(
            color: const Color(0xFF1A2033),
            elevation: 8,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 248,
                maxWidth: MediaQuery.sizeOf(context).width - 64,
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                children: [
                  for (final o in options)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        mine.contains(o) ? Icons.history : Icons.fitness_center,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                      title: Text(o, style: const TextStyle(fontSize: 16)),
                      onTap: () => onSelected(o),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 입력 묶음 하나를 약한 유리 카드로 (블러 없음: 스크롤 목록, docs/04 3장)
  Widget _card(List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: GlassPanel(
      level: GlassLevel.subtle,
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  Widget _tempoEditor(Routine r) {
    // null이면 직접 입력
    final selected = _customTempo
        ? null
        : _presetTempos.where((t) => t == r.tempo).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(context.l10n.tempoTitle),
        Wrap(
          spacing: 8,
          children: [
            for (final t in _presetTempos)
              ChoiceChip(
                label: Text('${_tempoName(t)} ${t.label}'),
                selected: selected == t,
                onSelected: (_) {
                  _customTempo = false;
                  _set(r.copyWith(tempo: t));
                },
              ),
            ChoiceChip(
              label: Text(context.l10n.custom),
              selected: selected == null,
              onSelected: (_) => setState(() => _customTempo = true),
            ),
          ],
        ),
        if (selected == null) ...[
          _TempoStepper(
            label: context.l10n.phaseDown,
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
            label: context.l10n.phaseHold,
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
            label: context.l10n.phaseUp,
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

String _fmtTime(AppLocalizations l, int ms) {
  final s = ms ~/ 1000;
  if (s < 60) return l.durationSeconds(s);
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
          tooltip: context.l10n.decreaseNamed(label),
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
          tooltip: context.l10n.increaseNamed(label),
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
    child: IconButton.filled(
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.10),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.04),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.25),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
      ),
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
    valueText: _fmtTime(context.l10n, ms),
    canDown: ms > min,
    canUp: ms < max,
    onDown: () =>
        onChanged(EditRules.stepTime(ms, up: false, min: min, max: max)),
    onUp: () => onChanged(EditRules.stepTime(ms, up: true, min: min, max: max)),
    onTapValue: () async {
      final v = await pickTime(context, label, ms);
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
    this.format,
  });
  final String label;
  final int value;
  final int min;
  final int max;

  /// 값 표기 (예: "12회"). 없으면 숫자만.
  final String Function(int)? format;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => _StepperRow(
    label: label,
    valueText: format?.call(value) ?? '$value',
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
    valueText: context.l10n.tempoSeconds(
      ms % 1000 == 0 ? '${ms ~/ 1000}' : (ms / 1000).toStringAsFixed(1),
    ),
    canDown: ms > min,
    canUp: ms < RoutineLimits.maxTempoMs,
    onDown: () => onChanged(EditRules.stepTempo(ms, up: false, min: min)),
    onUp: () => onChanged(EditRules.stepTempo(ms, up: true, min: min)),
  );
}

/// 값을 탭하면 `분:초` 휠 선택기 (docs/03 4장). 코스 편집에서도 쓴다.
Future<int?> pickTime(BuildContext context, String label, int ms) {
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
                      for (var i = 0; i < 100; i++)
                        Center(child: Text(c.l10n.durationMinutes(i))),
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
                      for (var i = 0; i < 60; i++)
                        Center(child: Text(c.l10n.durationSeconds(i))),
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
              child: Text(context.l10n.confirm),
            ),
          ),
        ],
      ),
    ),
  );
}
