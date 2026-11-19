// 앱 아이콘 PNG 생성기. 실행: flutter test tool/generate_app_icon_test.dart
// 결과: assets/icon/ (전체, 적응형 배경·전경). 그 뒤 dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fitness_timer/design/app_icon_painter.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _render(
  String path,
  AppIconPainter painter, {
  double size = 1024,
}) => _renderWith(
  path,
  size,
  (canvas) => painter.paint(canvas, ui.Size(size, size)),
);

Future<void> _renderWith(
  String path,
  double size,
  void Function(ui.Canvas) draw,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  draw(canvas);
  final image = await recorder.endRecording().toImage(
    size.toInt(),
    size.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
}

void main() {
  test('앱 아이콘 생성', () async {
    await Directory('assets/icon').create(recursive: true);
    await _render('assets/icon/app_icon.png', const AppIconPainter());
    await _render(
      'assets/icon/adaptive_background.png',
      const AppIconPainter(foreground: false),
    );
    await _render(
      'assets/icon/adaptive_foreground.png',
      const AppIconPainter(background: false),
    );

    // Android 12+ 시스템 시작 화면에 앱 아이콘이 자동으로 들어가지 않도록 투명 이미지
    await _renderWith('assets/icon/splash_android12_blank.png', 1152, (c) {});
  });
}
