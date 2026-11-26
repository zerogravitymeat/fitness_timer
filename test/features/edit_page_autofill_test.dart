import 'package:fitness_timer/features/edit/edit_page.dart';
import 'package:fitness_timer/l10n/l10n.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openNewRoutine(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ko'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: EditPage(initial: Routine(id: 'r1', name: ''), isNew: true),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickPlank(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, 'ㅍㄹㅋ');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '플랭크'));
    await tester.pump();
  }

  testWidgets('추천을 고르면 기본값 안내가 뜨고, 시간이 지나면 사라진다', (tester) async {
    await openNewRoutine(tester);
    await pickPlank(tester);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.text('플랭크 기본값으로 맞췄어요'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('플랭크 기본값으로 맞췄어요'), findsNothing);
  });

  testWidgets('되돌리기를 누르면 처음 설정으로 돌아간다', (tester) async {
    await openNewRoutine(tester);
    expect(find.text('40초'), findsOneWidget); // 기본 운동 40초

    await pickPlank(tester);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.text('40초'), findsNothing); // 플랭크 30초 / 30초

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(find.text('40초'), findsOneWidget);
  });
}
