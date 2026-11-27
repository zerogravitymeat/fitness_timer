import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 비프음 파일을 기기 저장소에 복사해 두고 그 폴더 경로를 돌려준다.
///
/// 포그라운드 서비스 isolate에서는 path_provider(→ jni)가
/// "ClassNotFoundException: android/content/Context"로 실패한다 (jni 1.2.0).
/// 그래서 복사는 화면(메인) isolate에서 하고, 서비스는 경로만 받아
/// `DeviceFileSource`로 재생한다. audioplayers의 AssetSource는 내부에서
/// path_provider를 쓰므로 서비스에서 쓰면 안 된다.
abstract final class SoundFiles {
  static const names = [
    'beep_low.wav',
    'beep_high.wav',
    'tick.wav',
    'beep_long.wav',
    'done.wav',
    'second_tick.wav',
    'second_tock.wav',
  ];

  static String? _dir;

  /// 메인 isolate에서만 호출한다.
  static Future<String> prepare() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/sounds');
    await dir.create(recursive: true);
    for (final name in names) {
      final data = await rootBundle.load('assets/sounds/$name');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final file = File('${dir.path}/$name');
      if (!await file.exists() || await file.length() != bytes.length) {
        await file.writeAsBytes(bytes, flush: true);
      }
    }
    return _dir = dir.path;
  }
}
