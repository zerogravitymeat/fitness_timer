import 'dart:convert';
import 'dart:io';

/// JSON 파일 하나를 안전하게 읽고 쓴다.
/// 화면 isolate와 서비스 isolate 양쪽에서 쓸 수 있다 (path_provider를 쓰지 않음).
class JsonFile {
  JsonFile(this.path);
  final String path;

  /// 없거나 깨져 있으면 null
  Future<Map<String, Object?>?> read() async {
    final f = File(path);
    try {
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString());
      return j is Map ? j.cast<String, Object?>() : null;
    } catch (_) {
      return null;
    }
  }

  /// 임시 파일에 쓴 뒤 이름을 바꿔서, 쓰는 도중 앱이 꺼져도 기존 파일이 깨지지 않게 한다
  Future<void> write(Map<String, Object?> data) async {
    final f = File(path);
    await f.parent.create(recursive: true);
    final tmp = File('$path.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(path);
  }

  Future<void> delete() async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
