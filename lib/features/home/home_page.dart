import 'dart:ui';

import 'package:flutter/material.dart';
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
    if (state == AppLifecycleState.resumed) _ent.refreshTrial();
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
        title: const Text('운동이 중간에 멈췄어요'),
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
            const Text('멈춘 곳부터 이어서 할까요?'),
            if (batteryLimited) ...[
              const SizedBox(height: 16),
              // 제조사 배터리 최적화가 앱을 종료했을 수 있다 (docs/05 6.3절 3차 방어)
              Text(
                '휴대폰의 배터리 최적화 때문에 멈췄을 수 있어요. '
                '배터리 설정에서 이 앱을 "제한 없음"으로 바꾸면 화면이 꺼져도 끊기지 않아요.',
                style: Theme.of(c).textTheme.bodySmall,
              ),
              TextButton(
                onPressed:
                    FlutterForegroundTask.openIgnoreBatteryOptimizationSettings,
                child: const Text('배터리 설정 열기'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'discard'),
            child: const Text('버리기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'restart'),
            child: const Text('처음부터'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, 'resume'),
            child: const Text('이어서 하기'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('코스에 루틴이 없어요. 수정해서 루틴을 넣어 주세요')),
      );
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
          .showSnackBar(const SnackBar(content: Text('타이머를 시작하지 못했어요')));
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
        builder: (_) => EditPage(initial: initial, isNew: isNew),
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
        title: Text('"${r.name}"을(를) 삭제할까요?'),
        content: inCourses == 0
            ? null
            : Text('이 루틴이 들어간 코스 $inCourses개에서도 빠져요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('삭제'),
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

  /// 맨 아래 "추가": 새 루틴 / 새 코스 고르기
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
                title: const Text('새 루틴'),
                subtitle: const Text('운동 방식과 시간·횟수를 정해 만들어요'),
                onTap: () => close(
                  () => _edit(EditRules.blank(_store.newId()), isNew: true),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text('새 코스'),
                // 코스는 내 루틴을 조합해서 만든다. 내 루틴이 없으면 만들 수 없다.
                subtitle: Text(
                  hasMine ? '내 루틴을 골라 이어서 하는 묶음을 만들어요' : '내 루틴을 먼저 만들어 주세요',
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

  void _newCourse() =>
      _editCourse(Course(id: _store.newCourseId(), name: '내 코스'), isNew: true);

  Future<void> _confirmDeleteCourse(Course c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('"${c.name}" 코스를 삭제할까요?'),
        content: const Text('코스에 들어 있던 루틴은 지워지지 않아요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('삭제'),
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
                  '${RoutineSummary.course(w)}\n${RoutineSummary.courseNames(w)}',
                ),
                isThreeLine: true,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('시작'),
                onTap: () => close(() => _startCourse(course)),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('수정'),
                onTap: () => close(() => _editCourse(course, isNew: false)),
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('복사해서 수정'),
                onTap: () => close(
                  () => _editCourse(
                    course.copyWith(
                      id: _store.newCourseId(),
                      name: _copyName(course.name),
                    ),
                    isNew: true,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('삭제'),
                onTap: () => close(() => _confirmDeleteCourse(course)),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _copyName(String name) {
    final base = name.length > RoutineLimits.maxNameLength - 3
        ? name.substring(0, RoutineLimits.maxNameLength - 3)
        : name;
    return '$base 복사';
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
                subtitle: Text(RoutineSummary.of(r)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('시작'),
                onTap: () => close(() => _start(r)),
              ),
              ListTile(
                leading: Icon(fav ? Icons.star : Icons.star_border),
                title: Text(fav ? '즐겨찾기 해제' : '즐겨찾기 추가'),
                onTap: () => close(() => _store.toggleFavorite(r.id)),
              ),
              if (!r.isPreset)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('수정'),
                  onTap: () => close(() => _edit(r, isNew: false)),
                ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('복사해서 수정'),
                onTap: () => close(() => _edit(_store.copyOf(r), isNew: true)),
              ),
              if (!r.isPreset)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('삭제'),
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

  /// 순서 편집: 손잡이(≡)나 항목을 끌어서 위아래로 옮긴다
  Widget _buildReorder(BuildContext context) {
    final presets = _store.presets;
    final mine = _store.myRoutines;
    final courses = _store.courses;
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
    Widget routines(List<Routine> items, void Function(int, int) move) =>
        list<Routine>(
          items,
          (r) => r.id,
          (r, i) => _ReorderTile(
            leading: _ModeBar(routine: r),
            title: r.name,
            subtitle: RoutineSummary.of(r),
            index: i,
          ),
          move,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('순서 편집'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _exitReorder,
            child: const Text(
              '완료',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
              '오른쪽 손잡이(≡)를 끌거나 항목을 길게 눌러 옮기세요. 같은 묶음 안에서만 옮길 수 있어요',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (courses.isNotEmpty) ...[
            const _Section('코스'),
            list<Course>(
              courses,
              (c) => c.id,
              (c, i) => _ReorderTile(
                leading: const _CourseMark(),
                title: c.name,
                subtitle: RoutineSummary.course(_store.workoutOf(c)),
                index: i,
              ),
              _store.moveCourse,
            ),
          ],
          if (mine.isNotEmpty) ...[
            const _Section('내 루틴'),
            routines(mine, _store.moveMine),
          ],
          const _Section('프리셋'),
          routines(presets, _store.movePreset),
        ],
      ),
    );
  }

  Widget _buildNormal(BuildContext context) {
    final ent = _ent.value;
    final recent = _store.recent;
    final favorites = _store.favorites;
    final mine = _store.myRoutines;
    final courses = _store.courses;
    final text = Theme.of(context).textTheme;

    // 섹션 제목 + 정렬 선택 (내 루틴, 코스)
    Widget sortHeader(
      String title,
      RoutineSort value,
      Future<void> Function(RoutineSort) onChanged,
    ) => Row(
      children: [
        Expanded(child: _Section(title)),
        DropdownButton<RoutineSort>(
          value: value,
          underline: const SizedBox.shrink(),
          onChanged: (s) => s == null ? null : onChanged(s),
          items: const [
            DropdownMenuItem(value: RoutineSort.custom, child: Text('직접 정렬')),
            DropdownMenuItem(value: RoutineSort.recent, child: Text('최근 사용순')),
            DropdownMenuItem(value: RoutineSort.name, child: Text('이름순')),
            DropdownMenuItem(value: RoutineSort.created, child: Text('만든 순')),
          ],
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitness Timer'),
        actions: [
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      // 맨 아래 가로 유리 버튼: 루틴이나 코스 추가 (docs/03 3장).
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
          8,
          16,
          _GlassAddButton.areaHeight +
              16 +
              MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          // 체험 중에만 "무료 운동 N회 남음" (docs/03 3장)
          if (ent.inTrial)
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.card_giftcard, size: 18),
                label: Text('무료 운동 ${ent.freeRemaining}회 남음'),
                onPressed: () => PaywallPage.open(context),
              ),
            ),
          if (recent != null) ...[
            const _Section('최근'),
            _RecentCard(
              routine: recent,
              locked: !ent.canStart(recent),
              onStart: () => _start(recent),
              onMenu: () => _menu(recent),
            ),
          ],
          if (favorites.isNotEmpty) ...[
            const _Section('즐겨찾기'),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: favorites.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final r = favorites[i];
                  return _FavoriteCard(
                    routine: r,
                    locked: !ent.canStart(r),
                    onStart: () => _start(r),
                    onMenu: () => _menu(r),
                  );
                },
              ),
            ),
          ],
          // 순서: 코스 → 내 루틴 → 프리셋 (docs/03 3장)
          if (courses.isNotEmpty) ...[
            sortHeader('코스', _store.courseSort, _store.setCourseSort),
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
          // 코스가 없으면 안내 (docs/03 3장)
          if (courses.isEmpty) ...[
            const _Section('코스'),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                mine.isEmpty ? '내 루틴을 먼저 만들면, 그 루틴들을 골라 코스로 묶을 수 있어요.' : '아래 "추가" 버튼으로 내 루틴을 골라 이어서 하는 코스를 만들어 보세요. 루틴 사이 휴식도 정할 수 있어요.',
                style: text.bodyMedium,
              ),
            ),
          ],
          sortHeader('내 루틴', _store.sort, _store.setSort),
          if (mine.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Text('자주 하는 운동을 루틴으로 저장해 보세요', style: text.bodyLarge),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('루틴 만들기'),
                    onPressed: () =>
                        _edit(EditRules.blank(_store.newId()), isNew: true),
                  ),
                ],
              ),
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
          const _Section('프리셋'),
          for (final r in _store.presets)
            _RoutineTile(
              routine: r,
              locked: !ent.canStart(r),
              favorite: _store.isFavorite(r.id),
              onStart: () => _start(r),
              onMenu: () => _menu(r),
              onLongPress: _enterReorder,
            ),
        ],
      ),
    );
  }
}

/// 순서 편집 모드의 항목: 탭·시작 버튼 없이 손잡이만
class _ReorderTile extends StatelessWidget {
  const _ReorderTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.index,
  });
  final Widget leading;
  final String title;
  final String subtitle;
  final int index;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: leading,
      title: Text(title, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      trailing: ReorderableDragStartListener(
        index: index,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.drag_handle_rounded, semanticLabel: '끌어서 옮기기'),
        ),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
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
      tooltip: locked ? '$name 잠김, 정식 버전에서 사용' : '$name 시작',
      icon: Icon(locked ? Icons.lock_outline : Icons.play_arrow),
      onPressed: onStart,
    ),
  );
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.routine,
    this.locked = false,
    required this.onStart,
    required this.onMenu,
  });
  final Routine routine;
  final bool locked;
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
            colors: [
              c.c1.withValues(alpha: locked ? 0.15 : 0.55),
              c.c1.withValues(alpha: 0),
            ],
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
                      Text(RoutineSummary.of(routine)),
                      Text(
                        RoutineSummary.estimate(routine),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _StartButton(
                  name: routine.name,
                  onStart: onStart,
                  size: 60,
                  locked: locked,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.routine,
    this.locked = false,
    required this.onStart,
    required this.onMenu,
  });
  final Routine routine;
  final bool locked;
  final VoidCallback onStart;
  final VoidCallback onMenu;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    child: Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onMenu,
        onLongPress: onMenu,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                routine.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(child: Text(RoutineSummary.estimate(routine))),
                  _StartButton(
                    name: routine.name,
                    onStart: onStart,
                    locked: locked,
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
          if (favorite)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.star, size: 16),
            ),
        ],
      ),
      subtitle: Text(
        '${RoutineSummary.of(routine)} · ${RoutineSummary.estimate(routine)}',
      ),
      trailing: _StartButton(
        name: routine.name,
        onStart: onStart,
        locked: locked,
      ),
    ),
  );
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
          Text(RoutineSummary.course(workout)),
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

/// 홈 맨 아래 "추가" 버튼: 블러 유리 + 위쪽 하이라이트 (docs/04 3장).
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
                child: const SizedBox(
                  height: height,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text(
                        '추가',
                        style: TextStyle(
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
