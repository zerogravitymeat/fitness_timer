import 'dart:io';

import 'package:fitness_timer/app/app_services.dart';
import 'package:fitness_timer/features/course/course_edit_page.dart';
import 'package:fitness_timer/l10n/l10n.dart';
import 'package:fitness_timer/models/course.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:fitness_timer/services/storage/routine_repository.dart';
import 'package:fitness_timer/services/storage/routine_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const count = 12;
  final ids = [for (var i = 0; i < count; i++) 'r$i'];

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('course_edit_test');
    final store = RoutineStore(RoutineRepository(dir));
    await store.load();
    for (final id in ids) {
      await store.save(Routine(id: id, name: '루틴 $id'));
    }
    AppServices.routines = store;
  });

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: CourseEditPage(
          initial: Course(
            id: 'c1',
            name: '코스',
            steps: [for (final id in ids) CourseStep(routineId: id)],
          ),
          isNew: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('왼쪽으로 밀면 빠지고, 되돌리기로 다시 들어온다', (tester) async {
    await open(tester);
    await tester.drag(find.text('루틴 r0'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('루틴 r0'), findsNothing);
    expect(find.text('"루틴 r0" 루틴을 뺐어요'), findsOneWidget);

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(find.text('루틴 r0'), findsOneWidget);
  });

  testWidgets('꾹 눌러 끌면 화면 끝에서 자동 스크롤되어 맨 아래로 옮길 수 있다', (tester) async {
    await open(tester);
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scroll.position.pixels, 0);

    final g = await tester.startGesture(tester.getCenter(find.text('루틴 r0')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    // 화면 맨 아래까지 끌고 버틴다
    for (var i = 0; i < 20; i++) {
      await g.moveBy(const Offset(0, 60));
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (var i = 0; i < 100; i++) {
      await g.moveBy(const Offset(0, 1));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(scroll.position.pixels, greaterThan(0));
    await g.up();
    await tester.pumpAndSettle();

    // 1번이 다른 루틴으로 바뀌었다 = r0이 아래로 옮겨졌다
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
    await tester.pumpAndSettle();
    expect(find.text('루틴 r1'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('루틴 r1')).dy,
      lessThan(tester.getTopLeft(find.text('루틴 r2')).dy),
    );
    expect(find.text('루틴 r0'), findsNothing);
  });

  testWidgets('끄는 루틴은 루틴 순서 영역 위로 벗어나지 않는다', (tester) async {
    await open(tester);
    final hintBottom = tester.getBottomLeft(find.textContaining('꾹 눌러')).dy;

    final g = await tester.startGesture(tester.getCenter(find.text('루틴 r0')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await g.moveBy(const Offset(0, -300));
    await tester.pump();
    // 끄는 동안 같은 이름이 두 개(자리 + 끄는 항목)라 위쪽 것을 본다
    final top = tester.getTopLeft(find.text('루틴 r0').hitTestable().last).dy;
    expect(top, greaterThanOrEqualTo(hintBottom));
    await g.up();
    await tester.pumpAndSettle();
  });
}
