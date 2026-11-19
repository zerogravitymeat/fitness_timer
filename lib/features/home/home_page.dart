import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../app/app_services.dart';
import '../../engine/timer_core.dart';
import '../../models/presets.dart';
import '../../models/routine.dart';
import '../../services/run/run_client.dart';
import '../../services/run/run_snapshot_store.dart';
import '../../services/storage/routine_repository.dart';
import '../../services/storage/routine_store.dart';
import '../common/routine_summary.dart';
import '../edit/edit_page.dart';
import '../edit/edit_rules.dart';
import '../run/run_page.dart';
import '../settings/settings_page.dart';

/// S1 홈 (docs/03_화면_설계.md 3장). 글래스 디자인은 개발 7단계에서 입힌다.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  RoutineStore get _store => AppServices.routines;

  @override
  void initState() {
    super.initState();
    // 앱을 다시 열었는데 운동이 진행 중이면 진행 화면으로 (docs/03 5.5절)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await RunClient.instance.reattach()) {
        if (mounted) _openRun();
        return;
      }
      // 서비스는 없는데 진행 상태가 남아 있으면 비정상 종료 (docs/03 D1)
      final saved = await AppServices.runSnapshots.load();
      if (saved != null && mounted) await _askResume(saved);
    });
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
                  ? saved.routine.name
                  : '${saved.routine.name} · ${saved.progressLabel}',
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
        await _start(saved.routine, restore: saved.checkpoint);
      case 'restart':
        await _start(saved.routine);
    }
  }

  Future<void> _start(Routine r, {EngineCheckpoint? restore}) async {
    final ok = await RunClient.instance.start(
      r,
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
    _store.markUsed(r.id);
    _openRun();
  }

  void _openRun() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RunPage()));
  }

  Future<void> _edit(Routine initial, {required bool isNew}) async {
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('"${r.name}"을(를) 삭제할까요?'),
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final recent = _store.recent;
        final favorites = _store.favorites;
        final mine = _store.myRoutines;
        final text = Theme.of(context).textTheme;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Fitness Timer'),
            actions: [
              IconButton(
                tooltip: '설정',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: '새 루틴 만들기',
            onPressed: () =>
                _edit(EditRules.blank(_store.newId()), isNew: true),
            child: const Icon(Icons.add),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (recent != null) ...[
                const _Section('최근'),
                _RecentCard(
                  routine: recent,
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
                        onStart: () => _start(r),
                        onMenu: () => _menu(r),
                      );
                    },
                  ),
                ),
              ],
              const _Section('프리셋'),
              for (final r in Presets.all)
                _RoutineTile(
                  routine: r,
                  favorite: _store.isFavorite(r.id),
                  onStart: () => _start(r),
                  onMenu: () => _menu(r),
                ),
              Row(
                children: [
                  const Expanded(child: _Section('내 루틴')),
                  DropdownButton<RoutineSort>(
                    value: _store.sort,
                    underline: const SizedBox.shrink(),
                    onChanged: (s) => s == null ? null : _store.setSort(s),
                    items: const [
                      DropdownMenuItem(
                        value: RoutineSort.recent,
                        child: Text('최근 사용순'),
                      ),
                      DropdownMenuItem(
                        value: RoutineSort.name,
                        child: Text('이름순'),
                      ),
                      DropdownMenuItem(
                        value: RoutineSort.created,
                        child: Text('만든 순'),
                      ),
                    ],
                  ),
                ],
              ),
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
                    favorite: _store.isFavorite(r.id),
                    onStart: () => _start(r),
                    onMenu: () => _menu(r),
                  ),
            ],
          ),
        );
      },
    );
  }
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
  });
  final String name;
  final VoidCallback onStart;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: IconButton.filled(
      // ListTile이 trailing 아이콘을 회색으로 칠하므로 색을 명시한다
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      tooltip: '$name 시작',
      icon: const Icon(Icons.play_arrow),
      onPressed: onStart,
    ),
  );
}

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
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
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
            _StartButton(name: routine.name, onStart: onStart, size: 60),
          ],
        ),
      ),
    ),
  );
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.routine,
    required this.onStart,
    required this.onMenu,
  });
  final Routine routine;
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
                  _StartButton(name: routine.name, onStart: onStart),
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
    required this.favorite,
    required this.onStart,
    required this.onMenu,
  });
  final Routine routine;
  final bool favorite;
  final VoidCallback onStart;
  final VoidCallback onMenu;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onMenu,
      onLongPress: onMenu,
      title: Row(
        children: [
          Flexible(child: Text(routine.name, overflow: TextOverflow.ellipsis)),
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
      trailing: _StartButton(name: routine.name, onStart: onStart),
    ),
  );
}
