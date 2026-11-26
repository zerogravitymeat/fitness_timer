import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../app/app_services.dart';
import '../../design/tokens.dart';
import '../../engine/timer_core.dart';
import '../../models/course.dart';
import '../../models/routine.dart';
import '../../models/workout.dart';
import '../../services/billing/entitlement_service.dart';
import '../../services/run/run_client.dart';
import '../../services/run/run_snapshot_store.dart';
import '../../services/storage/routine_repository.dart';
import '../../services/storage/routine_store.dart';
import '../common/routine_summary.dart';
import '../course/course_edit_page.dart';
import '../edit/edit_page.dart';
import '../edit/edit_rules.dart';
import '../paywall/paywall_page.dart';
import '../run/run_page.dart';
import '../settings/settings_page.dart';
import '../../l10n/l10n.dart';
import '../../services/app_language.dart';

/// S1 홈 (docs/03_화면_설계.md 3장). 글래스 디자인은 개발 7단계에서 입힌다.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  RoutineStore get _store => AppServices.routines;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 앱을 다시 열었는데 운동이 진행 중이면 진행 화면으로 (docs/03 5.5절)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ent.refreshTrial();
      if (await RunClient.instance.reattach()) {
        if (mounted) _openRun();
        return;
      }
      // 서비스는 없는데 진행 상태가 남아 있으면 비정상 종료 (docs/03 D1)
      final saved = await AppServices.runSnapshots.load();
      if (saved == null || !mounted) return;
      // 체험이 끝나 잠긴 루틴이면 이어하지 않고 버린다 (docs/02 10.3절)
      if (!_ent.value.canStartWorkout(saved.workout)) {
        await AppServices.runSnapshots.clear();
        return;
      }
      await _askResume(saved);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 앱으로 돌아올 때 무료 횟수 배지를 최신으로 (운동은 앱 밖에서도 끝날 수 있다)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ent.refreshTrial();
      AppLanguage.pullFromSystem(AppServices.settings);
    }
  }

  /// D1 이어하기 확인 (docs/03_화면_설계.md 8장)
  Future<void> _askResume(SavedRun saved) async {
    final batteryLimited =
        !await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!mounted) return;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text(context.l10n.interruptedTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 조사(을/를) 문제가 없도록 루틴 이름을 따로 보여준다
            Text(
              saved.progressLabel.isEmpty
                  ? saved.workout.name
                  : '${saved.workout.name} · ${saved.progressLabel}',
              style: Theme.of(c).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(context.l10n.resumeQuestion),
            if (batteryLimited) ...[
              const SizedBox(height: 16),
              // 제조사 배터리 최적화가 앱을 종료했을 수 있다 (docs/05 6.3절 3차 방어)
              Text(
                context.l10n.batteryHint,
                style: Theme.of(c).textTheme.bodySmall,
              ),
              TextButton(
                onPressed:
                    FlutterForegroundTask.openIgnoreBatteryOptimizationSettings,
                child: Text(context.l10n.openBatterySettings),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'discard'),
            child: Text(context.l10n.discard),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'restart'),
            child: Text(context.l10n.restartFromBeginning),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, 'resume'),
            child: Text(context.l10n.resumeWorkout),
          ),
        ],
      ),
    );
    await AppServices.runSnapshots.clear();
    switch (choice) {
      case 'resume':
        await _startWorkout(saved.workout, restore: saved.checkpoint);
      case 'restart':
        await _startWorkout(saved.workout);
    }
  }

  EntitlementService get _ent => AppServices.entitlement;

  /// 체험이 끝났으면 결제 화면을 띄우고, 구매하면 true (docs/02 10.3절)
  Future<bool> _requireCustom() async {
    if (_ent.value.canUseCustom) return true;
    return PaywallPage.open(context);
  }

  Future<void> _start(Routine r) => _startWorkout(Workout.single(r));

  Future<void> _startCourse(Course c) async {
    final w = _store.workoutOf(c);
    if (w.routines.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.courseEmptySnack)));
      return;
    }
    await _startWorkout(w);
  }

  /// 루틴 하나 또는 코스 시작. [restore]가 있으면 이어하기.
  Future<void> _startWorkout(Workout w, {EngineCheckpoint? restore}) async {
    // 앱이 닫혀 있는 동안 끝난 운동의 차감을 반영한다.
    // 오래된 값으로 판단하면 잠겨야 할 루틴이 시작될 수 있다.
    await _ent.refreshTrial();
    if (!mounted) return;
    if (!_ent.value.canStartWorkout(w) && !await PaywallPage.open(context)) {
      return;
    }
    if (!mounted) return;
    _ent.markRunStart();
    final ok = await RunClient.instance.start(
      w,
      settings: AppServices.settings.value,
      dataDir: AppServices.dataDir,
      restore: restore,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.timerStartFailed)));
      return;
    }
    _store.markUsed(w.courseId ?? w.routines.first.id);
    _openRun();
  }

  void _openRun() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RunPage()));
  }

  Future<void> _edit(Routine initial, {required bool isNew}) async {
    if (!await _requireCustom() || !mounted) return;
    final res = await Navigator.of(context).push<EditResult>(
      MaterialPageRoute(
        builder: (_) => EditPage(
          initial: initial,
          isNew: isNew,
          myRoutines: _store.myRoutines,
        ),
      ),
    );
    if (res == null) return;
    await _store.save(res.routine);
    if (res.start) await _start(res.routine);
  }

  Future<void> _confirmDelete(Routine r) async {
    final inCourses = _store.coursesUsing(r.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(context.l10n.deleteRoutineTitle(r.name)),
        content: inCourses == 0
            ? null
            : Text(context.l10n.deleteRoutineInCourses(inCourses)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true) await _store.delete(r.id);
  }

  // ── 코스 (docs/03 3장 "코스", 4-1장) ─────────────────

  Future<void> _editCourse(Course initial, {required bool isNew}) async {
    if (!await _requireCustom() || !mounted) return;
    final res = await Navigator.of(context).push<CourseEditResult>(
      MaterialPageRoute(
        builder: (_) => CourseEditPage(initial: initial, isNew: isNew),
      ),
    );
    if (res == null) return;
    await _store.saveCourse(res.course);
    if (res.start && mounted) await _startCourse(res.course);
  }

  /// 맨 아래 "새로 만들기": 새 루틴 / 기본 운동 복사 / 새 코스 (docs/03 3장)
  void _addMenu(bool hasMine) {
    showModalBottomSheet<void>(
      context: context,
      builder: (c) {
        void close(VoidCallback then) {
          Navigator.pop(c);
          then();
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(context.l10n.newRoutine),
                subtitle: Text(context.l10n.newRoutineSubtitle),
                onTap: () => close(
                  () => _edit(
                    EditRules.blank(
                      _store.newId(),
                      context.l10n.defaultRoutineName,
                    ),
                    isNew: true,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: Text(context.l10n.copyPreset),
                subtitle: Text(context.l10n.copyPresetSubtitle),
                onTap: () => close(_pickPresetToCopy),
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: Text(context.l10n.newCourse),
                // 코스는 내 루틴을 조합해서 만든다. 내 루틴이 없으면 만들 수 없다.
                subtitle: Text(
                  hasMine
                      ? context.l10n.newCourseSubtitle
                      : context.l10n.newCourseNeedsRoutine,
                ),
                enabled: hasMine,
                onTap: () => close(_newCourse),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 복사할 기본 운동 고르기 → 사본으로 편집
  Future<void> _pickPresetToCopy() async {
    // 체험이 끝났으면 고르기 전에 결제 화면부터
    if (!await _requireCustom() || !mounted) return;
    final picked = await showModalBottomSheet<Routine>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                context.l10n.pickPresetToCopy,
                style: Theme.of(c).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            for (final p in _store.presets)
              ListTile(
                leading: _PresetIcon(preset: p, size: 36),
                title: Text(p.name),
                subtitle: Text(RoutineSummary.of(context.l10n, p)),
                onTap: () => Navigator.pop(c, p),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await _edit(_store.copyOf(picked, context.l10n.copyName), isNew: true);
  }

  void _newCourse() => _editCourse(
    Course(id: _store.newCourseId(), name: context.l10n.defaultCourseName),
    isNew: true,
  );

  Future<void> _confirmDeleteCourse(Course c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(context.l10n.deleteCourseTitle(c.name)),
        content: Text(context.l10n.deleteCourseBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true) await _store.deleteCourse(c.id);
  }

  /// 코스 메뉴: 시작 / 수정 / 복사해서 수정 / 삭제
  void _courseMenu(Course course) {
    final w = _store.workoutOf(course);
    showModalBottomSheet<void>(
      context: context,
      builder: (c) {
        void close(VoidCallback then) {
          Navigator.pop(c);
          then();
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(course.name),
                subtitle: Text(
                  '${RoutineSummary.course(context.l10n, w)}\n${RoutineSummary.courseNames(w)}',
                ),
                isThreeLine: true,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: Text(context.l10n.start),
                onTap: () => close(() => _startCourse(course)),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(context.l10n.edit),
                onTap: () => close(() => _editCourse(course, isNew: false)),
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: Text(context.l10n.copyAndEdit),
                onTap: () => close(
                  () => _editCourse(
                    course.copyWith(
                      id: _store.newCourseId(),
                      name: RoutineStore.copyName(
                        course.name,
                        context.l10n.copyName,
                      ),
                    ),
                    isNew: true,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(context.l10n.delete),
                onTap: () => close(() => _confirmDeleteCourse(course)),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 루틴 메뉴 (docs/03 3장 "루틴 메뉴")
  void _menu(Routine r) {
    final fav = _store.isFavorite(r.id);
    showModalBottomSheet<void>(
      context: context,
      builder: (c) {
        void close(VoidCallback then) {
          Navigator.pop(c);
          then();
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(r.name),
                subtitle: Text(RoutineSummary.of(context.l10n, r)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: Text(context.l10n.start),
                onTap: () => close(() => _start(r)),
              ),
              // 프리셋은 즐겨찾기하지 않는다 (docs/03 3장 "루틴 메뉴")
              if (!r.isPreset)
                ListTile(
                  leading: Icon(fav ? Icons.star : Icons.star_border),
                  title: Text(
                    fav
                        ? context.l10n.favoriteRemove
                        : context.l10n.favoriteAdd,
                  ),
                  onTap: () => close(() => _store.toggleFavorite(r.id)),
                ),
              if (!r.isPreset)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(context.l10n.edit),
                  onTap: () => close(() => _edit(r, isNew: false)),
                ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: Text(context.l10n.copyAndEdit),
                onTap: () => close(
                  () => _edit(
                    _store.copyOf(r, context.l10n.copyName),
                    isNew: true,
                  ),
                ),
              ),
              if (!r.isPreset)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(context.l10n.delete),
                  onTap: () => close(() => _confirmDelete(r)),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 순서 편집 모드 (프리셋·내 루틴을 길게 누르면 들어간다)
  bool _reorder = false;

  void _enterReorder() {
    HapticFeedback.mediumImpact();
    setState(() => _reorder = true);
  }

  void _exitReorder() => setState(() => _reorder = false);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_store, _ent]),
      builder: (context, _) => PopScope(
        // 순서 편집 중 뒤로 가기는 편집 모드만 끝낸다
        canPop: !_reorder,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _reorder) _exitReorder();
        },
        child: _reorder ? _buildReorder(context) : _buildNormal(context),
      ),
    );
  }

  /// 순서 편집: 지금 보고 있는 탭(루틴 또는 코스)만 옮긴다 (docs/03 3장).
  /// 즐겨찾기 루틴은 즐겨찾기끼리만 옮긴다 (RoutineStore.moveMine).
  Widget _buildReorder(BuildContext context) {
    final courses = _store.homeTab == HomeTab.courses;
    Widget list<T>(
      List<T> items,
      String Function(T) id,
      Widget Function(T, int) tile,
      void Function(int, int) move,
    ) => ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      // onReorderItem은 옮긴 뒤 놓일 위치를 이미 보정해서 준다
      onReorderItem: (oldIndex, newIndex) {
        if (newIndex != oldIndex) {
          HapticFeedback.selectionClick();
          move(oldIndex, newIndex);
        }
      },
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(18),
        child: child,
      ),
      itemBuilder: (_, i) => ReorderableDelayedDragStartListener(
        key: ValueKey(id(items[i])),
        index: i,
        child: tile(items[i], i),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.reorderTitle),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _exitReorder,
            child: Text(
              context.l10n.done,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text(
              context.l10n.reorderHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          _Section(courses ? context.l10n.courses : context.l10n.myRoutines),
          if (courses)
            list<Course>(
              _store.courses,
              (c) => c.id,
              (c, i) => _ReorderTile(
                leading: const _CourseMark(),
                title: c.name,
                subtitle: RoutineSummary.course(
                  context.l10n,
                  _store.workoutOf(c),
                ),
                index: i,
              ),
              _store.moveCourse,
            )
          else
            list<Routine>(
              _store.myRoutines,
              (r) => r.id,
              (r, i) => _ReorderTile(
                leading: _ModeBar(routine: r),
                title: r.name,
                favorite: _store.isFavorite(r.id),
                subtitle: RoutineSummary.of(context.l10n, r),
                index: i,
              ),
              _store.moveMine,
            ),
        ],
      ),
    );
  }

  Widget _buildNormal(BuildContext context) {
    final ent = _ent.value;
    final recent = _store.recent;
    final mine = _store.myRoutines;
    final courses = _store.courses;

    // 처음 사용: 내 루틴·코스 모두 없음. 체험 종료: 실행할 수 있는 기본 운동을 위로
    // (docs/03 3장 "영역 순서")
    final firstRun = mine.isEmpty && courses.isEmpty;
    final basicFirst = firstRun || ent.trialEnded;

    // 체험 종료 후에는 실행할 수 있는 루틴(프리셋)일 때만
    final recentSection = recent != null && ent.canStart(recent)
        ? [
            _Section(context.l10n.recentWorkout),
            _RecentCard(
              routine: recent,
              onStart: () => _start(recent),
              onMenu: () => _menu(recent),
            ),
          ]
        : const <Widget>[];

    final basicSection = [
      if (firstRun)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.basicWorkoutsFirstTitle,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const _FreePill(),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      context.l10n.basicWorkoutsFirstBody,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
      else
        _Section(context.l10n.basicWorkouts, badge: const _FreePill()),
      _PresetGrid(presets: _store.presets, onStart: _start, onMenu: _menu),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitness Timer'),
        actions: [
          // 체험 중 "무료 N회", 체험 종료 후 "정식 버전". 누르면 S6 (docs/03 3장)
          if (!ent.isFull)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _PlanBadge(
                label: ent.trialEnded
                    ? context.l10n.fullVersion
                    : context.l10n.freeBadge(ent.freeRemaining),
                strong: ent.trialEnded,
                onPressed: () => PaywallPage.open(context),
              ),
            ),
          IconButton(
            tooltip: context.l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      // 맨 아래 가로 유리 버튼: 새로 만들기 (docs/03 3장).
      // 목록이 버튼 뒤로 지나가도록 본문을 아래까지 늘린다.
      extendBody: true,
      // 버튼 뒤로는 목록이 서서히 사라지게 (시스템 내비게이션 바 뒤까지 덮는다)
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, 0.45, 1],
            colors: [
              AppColors.bgBase.withValues(alpha: 0),
              AppColors.bgBase.withValues(alpha: 0.80),
              AppColors.bgBase, // 시스템 내비게이션 바 뒤로 목록이 비치지 않게
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              _GlassAddButton.barTop,
              20,
              _GlassAddButton.barBottom,
            ),
            child: _GlassAddButton(onPressed: () => _addMenu(mine.isNotEmpty)),
          ),
        ),
      ),
      body: ListView(
        // 마지막 항목이 추가 버튼에 가리지 않게: 버튼 영역 + 시스템 내비게이션 바 + 여유.
        // 이 context는 Scaffold 바깥이라 paddingOf에는 시스템 내비게이션 바 높이만 들어 있다.
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          _GlassAddButton.areaHeight +
              16 +
              MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ...recentSection,
          if (basicFirst) ...basicSection,
          ..._myWorkouts(context, mine, courses),
          if (!basicFirst) ...basicSection,
        ],
      ),
    );
  }

  /// "내 운동": [루틴 | 코스] 전환 + 고른 쪽 목록 (docs/03 3장 "내 운동")
  List<Widget> _myWorkouts(
    BuildContext context,
    List<Routine> mine,
    List<Course> courses,
  ) {
    final ent = _ent.value;

    // 아무것도 없으면 전환 버튼 없이 루틴 만들기 안내만
    if (mine.isEmpty && courses.isEmpty) {
      return [
        _Section(context.l10n.myWorkouts),
        _EmptyCard(
          message: context.l10n.routinesEmpty,
          action: context.l10n.createRoutine,
          onAction: _newRoutine,
        ),
      ];
    }

    final tab = _store.homeTab;
    final showCourses = tab == HomeTab.courses;
    return [
      _Section(
        context.l10n.myWorkouts,
        locked: ent.trialEnded,
        trailing: _SortButton(
          value: showCourses ? _store.courseSort : _store.sort,
          onChanged: showCourses ? _store.setCourseSort : _store.setSort,
        ),
      ),
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<HomeTab>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: HomeTab.routines,
              label: Text(context.l10n.tabRoutines(mine.length)),
            ),
            ButtonSegment(
              value: HomeTab.courses,
              label: Text(context.l10n.tabCourses(courses.length)),
            ),
          ],
          selected: {tab},
          onSelectionChanged: (s) => _store.setHomeTab(s.first),
        ),
      ),
      const SizedBox(height: 8),
      if (ent.trialEnded)
        _LockedBanner(onPressed: () => PaywallPage.open(context)),
      if (!showCourses) ...[
        if (mine.isEmpty)
          _EmptyCard(
            message: context.l10n.routinesEmpty,
            action: context.l10n.createRoutine,
            onAction: _newRoutine,
          )
        else
          for (final r in mine)
            _RoutineTile(
              routine: r,
              locked: !ent.canStart(r),
              favorite: _store.isFavorite(r.id),
              onStart: () => _start(r),
              onMenu: () => _menu(r),
              onLongPress: _enterReorder,
            ),
      ] else ...[
        if (courses.isEmpty)
          mine.isEmpty
              ? _EmptyCard(message: context.l10n.courseEmptyNoRoutines)
              : _EmptyCard(
                  message: context.l10n.courseEmptyHint,
                  action: context.l10n.createCourse,
                  onAction: _newCourse,
                )
        else
          for (final c in courses)
            _CourseTile(
              course: c,
              workout: _store.workoutOf(c),
              locked: !ent.canUseCustom,
              onStart: () => _startCourse(c),
              onMenu: () => _courseMenu(c),
              onLongPress: _enterReorder,
            ),
      ],
    ];
  }

  void _newRoutine() => _edit(
    EditRules.blank(_store.newId(), context.l10n.defaultRoutineName),
    isNew: true,
  );
}

/// 순서 편집 모드의 항목: 탭·시작 버튼 없이 손잡이만
class _ReorderTile extends StatelessWidget {
  const _ReorderTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.index,
    this.favorite = false,
  });
  final Widget leading;
  final String title;
  final String subtitle;
  final int index;
  final bool favorite;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: leading,
      title: Row(
        children: [
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
          if (favorite) const _FavoriteStar(),
        ],
      ),
      subtitle: Text(subtitle),
      trailing: ReorderableDragStartListener(
        index: index,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.drag_handle_rounded,
            semanticLabel: context.l10n.dragToMove,
          ),
        ),
      ),
    ),
  );
}

/// 홈 영역 제목 (docs/03 3장). 영역 사이를 넓게 띄워 묶음이 보이게 한다.
class _Section extends StatelessWidget {
  const _Section(this.title, {this.badge, this.trailing, this.locked = false});
  final String title;
  final Widget? badge;
  final Widget? trailing;

  /// 체험 종료 후 "내 운동" 제목 옆 자물쇠
  final bool locked;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(4, 28, trailing == null ? 4 : 0, 10),
    child: SizedBox(
      // 오른쪽 버튼이 있든 없든 제목 높이를 같게
      height: 36,
      child: Row(
        children: [
          // 제목·자물쇠·배지는 왼쪽에 모으고, 오른쪽 버튼은 맨 끝에
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (locked)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ),
                if (badge != null) ...[const SizedBox(width: 8), badge!],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    ),
  );
}

/// "항상 무료" 표시 (기본 운동 제목 옆)
class _FreePill extends StatelessWidget {
  const _FreePill();

  @override
  Widget build(BuildContext context) {
    final mint = PhaseColors.rest.c1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: mint.withValues(alpha: 0.14),
        border: Border.all(color: mint.withValues(alpha: 0.40)),
      ),
      child: Text(
        context.l10n.alwaysFree,
        style: TextStyle(
          color: Color.lerp(mint, Colors.white, 0.25),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 앱바의 "무료 N회" / "정식 버전" 배지. 누르면 결제 화면
class _PlanBadge extends StatelessWidget {
  const _PlanBadge({
    required this.label,
    required this.onPressed,
    this.strong = false,
  });
  final String label;
  final VoidCallback onPressed;

  /// 체험 종료 후: 채운 버튼으로 더 눈에 띄게
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
          )
        : FilledButton.styleFrom(
            backgroundColor: AppColors.accent.withValues(alpha: 0.16),
            foregroundColor: const Color(0xFFD3D8FF),
            side: BorderSide(color: AppColors.accent.withValues(alpha: 0.45)),
          );
    return FilledButton.icon(
      style: style.copyWith(
        visualDensity: VisualDensity.compact,
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      icon: Icon(strong ? Icons.star_rounded : Icons.card_giftcard, size: 16),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}

/// 정렬 고르기 (⇅). 지금 보고 있는 탭의 정렬을 바꾼다.
class _SortButton extends StatelessWidget {
  const _SortButton({required this.value, required this.onChanged});
  final RoutineSort value;
  final Future<void> Function(RoutineSort) onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = {
      RoutineSort.custom: l.sortCustom,
      RoutineSort.recent: l.sortRecent,
      RoutineSort.name: l.sortName,
      RoutineSort.created: l.sortCreated,
    };
    return PopupMenuButton<RoutineSort>(
      tooltip: '${l.sortTooltip}: ${labels[value]}',
      icon: const Icon(Icons.swap_vert_rounded),
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final e in labels.entries)
          CheckedPopupMenuItem(
            value: e.key,
            checked: e.key == value,
            child: Text(e.value),
          ),
      ],
    );
  }
}

/// 비어 있을 때 안내 (+ 만들기 버튼)
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message, this.action, this.onAction});
  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.panel),
      color: Colors.white.withValues(alpha: GlassLevel.subtle.fill),
      border: Border.all(
        color: Colors.white.withValues(alpha: GlassLevel.subtle.border),
      ),
    ),
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: AppColors.textSecondary, height: 1.5),
        ),
        if (action != null) ...[
          const SizedBox(height: 14),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: Text(action!),
            onPressed: onAction,
          ),
        ],
      ],
    ),
  );
}

/// 체험 종료 후 "내 운동" 맨 위 안내 (docs/03 3장)
class _LockedBanner extends StatelessWidget {
  const _LockedBanner({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 5),
    padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.small),
      color: AppColors.accent.withValues(alpha: 0.14),
      border: Border.all(color: AppColors.accent.withValues(alpha: 0.30)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.lockedMineBanner,
            style: const TextStyle(color: Color(0xFFE3E6FF), height: 1.4),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: onPressed,
          child: Text(context.l10n.lockedMineAction),
        ),
      ],
    ),
  );
}

class _FavoriteStar extends StatelessWidget {
  const _FavoriteStar();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: Icon(
      Icons.star_rounded,
      size: 16,
      color: PhaseColors.prep.c1,
      semanticLabel: context.l10n.favorites,
    ),
  );
}

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.name,
    required this.onStart,
    this.size = 44,
    this.locked = false,
  });
  final String name;
  final VoidCallback onStart;
  final double size;

  /// 체험이 끝난 내 루틴: ▶ 대신 자물쇠, 누르면 결제 화면 (docs/03 3장)
  final bool locked;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: IconButton.filled(
      // ListTile이 trailing 아이콘을 회색으로 칠하므로 색을 명시한다
      style: IconButton.styleFrom(
        backgroundColor: locked
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).colorScheme.primary,
        foregroundColor: locked
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : Theme.of(context).colorScheme.onPrimary,
      ),
      tooltip: locked
          ? context.l10n.lockedNamed(name)
          : context.l10n.startNamed(name),
      icon: Icon(locked ? Icons.lock_outline : Icons.play_arrow),
      onPressed: onStart,
    ),
  );
}

/// 최근 운동: 가장 큰 카드. 실행할 수 있을 때만 보여주므로 잠금 표시는 없다.
class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.routine,
    required this.onStart,
    required this.onMenu,
  });
  final Routine routine;
  final VoidCallback onStart;
  final VoidCallback onMenu;
  @override
  Widget build(BuildContext context) {
    final c = _modeColors(routine);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-1, -1),
            radius: 1.6,
            colors: [c.c1.withValues(alpha: 0.55), c.c1.withValues(alpha: 0)],
          ),
        ),
        child: InkWell(
          onTap: onMenu,
          onLongPress: onMenu,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routine.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(RoutineSummary.of(context.l10n, routine)),
                      Text(
                        RoutineSummary.estimate(context.l10n, routine),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _StartButton(name: routine.name, onStart: onStart, size: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutineTile extends StatelessWidget {
  const _RoutineTile({
    required this.routine,
    this.locked = false,
    required this.favorite,
    required this.onStart,
    required this.onMenu,
    required this.onLongPress,
  });
  final Routine routine;
  final bool locked;
  final bool favorite;
  final VoidCallback onStart;
  final VoidCallback onMenu;

  /// 길게 누르면 순서 편집 모드
  final VoidCallback onLongPress;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onMenu,
      onLongPress: onLongPress,
      leading: _ModeBar(routine: routine, dim: locked),
      title: Row(
        children: [
          Flexible(
            child: Text(
              routine.name,
              overflow: TextOverflow.ellipsis,
              style: locked
                  ? TextStyle(color: Theme.of(context).disabledColor)
                  : null,
            ),
          ),
          if (favorite) const _FavoriteStar(),
        ],
      ),
      // 예상 시간("about 4 min")은 줄바꿈 때 쪼개지지 않게 한 덩어리로
      subtitle: Text(
        '${RoutineSummary.of(context.l10n, routine)} · '
        '${RoutineSummary.estimate(context.l10n, routine).replaceAll(' ', ' ')}',
      ),
      trailing: _StartButton(
        name: routine.name,
        onStart: onStart,
        locked: locked,
      ),
    ),
  );
}

/// 기본 운동마다 아이콘과 색 (docs/03 3장 "기본 운동 카드")
(IconData, PhaseColors) _presetStyle(Routine p) => switch (p.id) {
  'preset_tabata' => (Icons.bolt_rounded, PhaseColors.work),
  'preset_hiit' => (Icons.local_fire_department_rounded, PhaseColors.prep),
  'preset_plank' => (Icons.timer_outlined, PhaseColors.rest),
  _ => (Icons.fitness_center_rounded, PhaseColors.setRest),
};

class _PresetIcon extends StatelessWidget {
  const _PresetIcon({required this.preset, this.size = 40});
  final Routine preset;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, c) = _presetStyle(preset);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.33),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.c1, c.c2],
        ),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

/// 기본 운동 2×2 격자. 순서는 바꿀 수 없다.
class _PresetGrid extends StatelessWidget {
  const _PresetGrid({
    required this.presets,
    required this.onStart,
    required this.onMenu,
  });
  final List<Routine> presets;
  final void Function(Routine) onStart;
  final void Function(Routine) onMenu;

  @override
  Widget build(BuildContext context) {
    Widget card(Routine p) => _PresetCard(
      preset: p,
      onStart: () => onStart(p),
      onMenu: () => onMenu(p),
    );
    return Column(
      children: [
        for (var i = 0; i < presets.length; i += 2)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            // 한 줄의 두 카드 높이를 맞춘다 (글자 크기가 커져도)
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: card(presets[i])),
                  const SizedBox(width: 10),
                  Expanded(
                    child: i + 1 < presets.length
                        ? card(presets[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.onStart,
    required this.onMenu,
  });
  final Routine preset;
  final VoidCallback onStart;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      // 내 루틴 목록보다 한 단계 밝은 유리로 구분한다
      color: Colors.white.withValues(alpha: GlassLevel.regular.fill - 0.02),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onMenu,
        onLongPress: onMenu,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PresetIcon(preset: preset, size: 36),
              const SizedBox(height: 10),
              Text(
                preset.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                RoutineSummary.of(context.l10n, preset),
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      RoutineSummary.estimate(context.l10n, preset),
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  _StartButton(name: preset.name, onStart: onStart, size: 40),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

PhaseColors _modeColors(Routine r) =>
    r.isReps ? PhaseColors.setRest : PhaseColors.work;

/// 루틴 종류를 색으로 구분하는 작은 막대 (docs/04 시안의 홈)
class _ModeBar extends StatelessWidget {
  const _ModeBar({required this.routine, this.dim = false});
  final Routine routine;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final c = _modeColors(routine);
    return Opacity(
      opacity: dim ? 0.35 : 1,
      child: Container(
        width: 6,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.c1, c.c2],
          ),
        ),
      ),
    );
  }
}

/// 코스 표시: 막대 세 개 (루틴 여러 개가 이어진 모양)
class _CourseMark extends StatelessWidget {
  const _CourseMark({this.dim = false});
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final colors = [PhaseColors.work, PhaseColors.rest, PhaseColors.setRest];
    return Opacity(
      opacity: dim ? 0.35 : 1,
      child: SizedBox(
        width: 22,
        height: 36,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final c in colors)
              Container(
                width: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.c1, c.c2],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 코스 항목: 이름, 루틴 순서, 루틴 수·예상 시간 (docs/03 3장 "코스 항목")
class _CourseTile extends StatelessWidget {
  const _CourseTile({
    required this.course,
    required this.workout,
    this.locked = false,
    required this.onStart,
    required this.onMenu,
    required this.onLongPress,
  });
  final Course course;
  final Workout workout;
  final bool locked;
  final VoidCallback onStart;
  final VoidCallback onMenu;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onMenu,
      onLongPress: onLongPress,
      leading: _CourseMark(dim: locked),
      title: Text(
        course.name,
        overflow: TextOverflow.ellipsis,
        style: locked
            ? TextStyle(color: Theme.of(context).disabledColor)
            : null,
      ),
      // 루틴 순서는 한 줄로 줄이고, 루틴 수·예상 시간은 항상 보이게
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            RoutineSummary.courseNames(workout),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(RoutineSummary.course(context.l10n, workout)),
        ],
      ),
      isThreeLine: true,
      trailing: _StartButton(
        name: course.name,
        onStart: onStart,
        locked: locked,
      ),
    ),
  );
}

/// 홈 맨 아래 "새로 만들기" 버튼: 블러 유리 + 위쪽 하이라이트 (docs/04 3장).
/// 화면에 하나뿐이라 BackdropFilter를 써도 부담이 적다.
class _GlassAddButton extends StatelessWidget {
  const _GlassAddButton({required this.onPressed});
  final VoidCallback onPressed;

  /// 버튼 높이와 위아래 여백. 홈 목록의 아래 여백 계산에도 쓴다.
  static const height = 56.0;
  static const barTop = 28.0;
  static const barBottom = 14.0;
  static const areaHeight = barTop + height + barBottom;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(AppRadius.button);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              // 위는 조금 밝고 아래는 투명한 유리
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.20),
                  Colors.white.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: r,
                onTap: onPressed,
                child: SizedBox(
                  height: height,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.createNew,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
