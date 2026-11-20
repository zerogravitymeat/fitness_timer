import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_services.dart';
import '../../design/glass.dart';
import '../../design/tokens.dart';
import '../../models/course.dart';
import '../../models/routine.dart';
import '../../services/run/run_labels.dart';
import '../common/routine_summary.dart';
import '../edit/edit_page.dart' show pickTime;
import '../edit/edit_rules.dart';
import '../../l10n/l10n.dart';

/// 코스 편집 결과. [start]가 true면 저장 후 바로 시작.
class CourseEditResult {
  const CourseEditResult(this.course, {required this.start});
  final Course course;
  final bool start;
}

/// S7 코스 편집 (docs/03_화면_설계.md 4-1장).
/// 루틴을 넣고, 끌어서 순서를 바꾸고, 루틴 사이 휴식을 정한다.
class CourseEditPage extends StatefulWidget {
  const CourseEditPage({super.key, required this.initial, required this.isNew});

  final Course initial;
  final bool isNew;

  @override
  State<CourseEditPage> createState() => _CourseEditPageState();
}

/// 편집 중인 항목. 같은 루틴을 여러 번 넣을 수 있어서 목록 키를 따로 둔다.
class _Item {
  _Item(this.step) : key = UniqueKey();
  CourseStep step;
  final Key key;
}

class _CourseEditPageState extends State<CourseEditPage> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final List<_Item> _items = [
    // 지워진 루틴은 편집 화면에서도 보이지 않게
    for (final s in widget.initial.steps)
      if (AppServices.routines.byId(s.routineId) != null) _Item(s),
  ];

  Course get _course => widget.initial.copyWith(
    name: _name.text.trim(),
    steps: [for (final i in _items) i.step],
  );

  bool get _dirty =>
      widget.isNew ||
      !_course.sameAs(widget.initial.copyWith(name: widget.initial.name));

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

  Routine? _routine(_Item i) => AppServices.routines.byId(i.step.routineId);

  Future<void> _add() async {
    if (_items.length >= CourseLimits.maxSteps) return;
    final r = await showModalBottomSheet<Routine>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _RoutinePicker(),
    );
    if (r == null) return;
    setState(() => _items.add(_Item(CourseStep(routineId: r.id))));
  }

  Future<void> _editRest(_Item item) async {
    final v = await showModalBottomSheet<int>(
      context: context,
      builder: (c) => _RestSheet(current: item.step.restAfterMs),
    );
    if (v == null) return;
    setState(
      () => item.step = item.step.copyWith(
        restAfterMs: v.clamp(0, CourseLimits.maxRestMs),
      ),
    );
  }

  void _finish({required bool start}) {
    final name = EditRules.validName(_name.text);
    if (name == null || _items.isEmpty) return;
    Navigator.of(context).pop(
      CourseEditResult(_course.copyWith(name: name).normalized(), start: start),
    );
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
    final nameOk = EditRules.validName(_name.text) != null;
    final canSave = nameOk && _items.isNotEmpty;
    final workout = AppServices.routines.workoutOf(_course);
    final text = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isNew ? context.l10n.newCourse : context.l10n.editCourse,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            GlassPanel(
              level: GlassLevel.subtle,
              radius: 20,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _name,
                maxLength: RoutineLimits.maxNameLength,
                decoration: InputDecoration(
                  labelText: context.l10n.name,
                  errorText: nameOk ? null : context.l10n.nameRequired,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 20, 4, 4),
              child: Text(context.l10n.routineOrder, style: text.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                _items.isEmpty
                    ? context.l10n.courseOrderHintEmpty
                    : context.l10n.courseOrderHint,
                style: text.bodySmall,
              ),
            ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _items.length,
              onReorderItem: (o, n) {
                if (o == n) return;
                HapticFeedback.selectionClick();
                setState(() => _items.insert(n, _items.removeAt(o)));
              },
              proxyDecorator: (child, index, animation) => Material(
                color: Colors.transparent,
                elevation: 8,
                shadowColor: Colors.black54,
                borderRadius: BorderRadius.circular(18),
                child: child,
              ),
              itemBuilder: (_, i) {
                final item = _items[i];
                final r = _routine(item);
                return Column(
                  key: item.key,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        contentPadding: const EdgeInsets.only(
                          left: 16,
                          right: 4,
                        ),
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          foregroundColor: Colors.white,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        title: Text(
                          r?.name ?? context.l10n.deletedRoutine,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: r == null
                            ? null
                            : Text(
                                '${RoutineSummary.of(context.l10n, r)} · ${RoutineSummary.estimate(context.l10n, r)}',
                              ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: context.l10n.removeNamed(
                                r?.name ?? context.l10n.routine,
                              ),
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () =>
                                  setState(() => _items.removeAt(i)),
                            ),
                            ReorderableDragStartListener(
                              index: i,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.drag_handle_rounded,
                                  semanticLabel: context.l10n.dragToMove,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 마지막 루틴 뒤에는 휴식이 없다
                    if (i < _items.length - 1)
                      _RestChip(
                        ms: item.step.restAfterMs,
                        onTap: () => _editRest(item),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.add),
              label: Text(
                _items.length >= CourseLimits.maxSteps
                    ? context.l10n.maxSteps(CourseLimits.maxSteps)
                    : context.l10n.addRoutine,
              ),
              onPressed: _items.length >= CourseLimits.maxSteps ? null : _add,
            ),
          ],
        ),
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
                    _items.isEmpty
                        ? context.l10n.needOneRoutine
                        : RoutineSummary.course(context.l10n, workout),
                    style: text.titleMedium?.copyWith(
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
                          onPressed: canSave
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
                          onPressed: canSave
                              ? () => _finish(start: true)
                              : null,
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
}

/// 루틴 사이의 휴식 표시. 누르면 바꾼다.
class _RestChip extends StatelessWidget {
  const _RestChip({required this.ms, required this.onTap});
  final int ms;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final none = ms <= 0;
    final color = none
        ? Colors.white.withValues(alpha: 0.55)
        : PhaseColors.rest.c1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const SizedBox(width: 30),
          Container(
            width: 2,
            height: 36,
            color: Colors.white.withValues(alpha: 0.18),
          ),
          const SizedBox(width: 12),
          ActionChip(
            avatar: Icon(
              none ? Icons.fast_forward_rounded : Icons.self_improvement,
              size: 18,
              color: color,
            ),
            label: Text(
              none
                  ? context.l10n.noRest
                  : context.l10n.restWith(RunLabels.duration(context.l10n, ms)),
              style: TextStyle(color: color),
            ),
            tooltip: context.l10n.changeCourseRest,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

/// 루틴 사이 휴식 고르기: 없음 / 자주 쓰는 값 / 직접
class _RestSheet extends StatelessWidget {
  const _RestSheet({required this.current});
  final int current;

  static const _choices = [0, 15000, 30000, 60000, 90000, 120000, 180000];

  @override
  Widget build(BuildContext context) {
    final custom = !_choices.contains(current);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.courseRest,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.courseRestNoneHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final ms in _choices)
                  ChoiceChip(
                    label: Text(
                      ms == 0
                          ? context.l10n.none
                          : RunLabels.duration(context.l10n, ms),
                    ),
                    selected: ms == current,
                    onSelected: (_) => Navigator.pop(context, ms),
                  ),
                ChoiceChip(
                  label: Text(
                    custom
                        ? context.l10n.customWith(
                            RunLabels.duration(context.l10n, current),
                          )
                        : context.l10n.custom,
                  ),
                  selected: custom,
                  onSelected: (_) async {
                    final nav = Navigator.of(context);
                    final v = await pickTime(
                      context,
                      context.l10n.courseRest,
                      current,
                    );
                    if (v != null) nav.pop(v);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 코스에 넣을 루틴 고르기 (내 루틴만)
class _RoutinePicker extends StatelessWidget {
  const _RoutinePicker();

  @override
  Widget build(BuildContext context) {
    final store = AppServices.routines;
    final mine = store.myRoutines;
    Widget tile(Routine r) => ListTile(
      title: Text(r.name),
      subtitle: Text(
        '${RoutineSummary.of(context.l10n, r)} · ${RoutineSummary.estimate(context.l10n, r)}',
      ),
      trailing: const Icon(Icons.add_circle_outline),
      onTap: () => Navigator.pop(context, r),
    );
    Widget header(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(t, style: Theme.of(context).textTheme.titleSmall),
    );
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, controller) => ListView(
        controller: controller,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              context.l10n.addRoutine,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          // 코스는 내 루틴을 조합해서 만든다 (docs/02 8-1장)
          header(context.l10n.myRoutines),
          for (final r in mine) tile(r),
          if (mine.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.l10n.noMyRoutines),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
