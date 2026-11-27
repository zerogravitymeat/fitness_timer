import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:fitness_timer/features/edit/edit_page.dart';
import 'package:fitness_timer/l10n/l10n.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 휠을 [items]칸 아래로 굴린다
  Future<void> roll(WidgetTester tester, Finder wheel, int items) async {
    await tester.drag(wheel, Offset(0, -40.0 * items - 10));
    await tester.pumpAndSettle();
  }

  testWidgets('준비 시간을 1분 30초로 고르면 그대로 남는다', (tester) async {
    await pump(
      tester,
      const EditPage(initial: Routine(id: 'r1', name: 'a'), isNew: true),
    );
    await tester.tap(find.text('10초').first);
    await tester.pumpAndSettle();

    final wheels = find.byType(CupertinoPicker);
    await roll(tester, wheels.first, 1); // 1분
    await roll(tester, wheels.last, 20); // 10초 → 30초
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('1:30'), findsOneWidget);
  });

  testWidgets('최대 분을 고르면 초는 최대값까지만 고를 수 있다', (tester) async {
    int? picked;
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              picked = await pickTime(context, 't', 30000, max: 90000),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('2분'), findsNothing);

    final wheels = find.byType(CupertinoPicker);
    await roll(tester, wheels.first, 5); // 1분이 끝
    expect(find.text('31초'), findsNothing);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(picked, 90000);
  });
}
