import 'package:flutter_tts/flutter_tts.dart';

/// 기기 TTS 엔진에 설치된 음성 목록.
class TtsVoices {
  TtsVoices._();

  /// [ttsLanguage] (예: "ko-KR")로 바로 쓸 수 있는 음성. 이름 순.
  /// 인터넷이 필요한 음성, 데이터가 설치되지 않은 음성은 뺀다.
  /// 반환값은 [FlutterTts.setVoice]에 그대로 넘길 수 있는 {name, locale}.
  static Future<List<Map<String, String>>> installed(
    FlutterTts tts,
    String ttsLanguage,
  ) async {
    final List<Object?> raw;
    try {
      raw =
          await tts.getVoices.timeout(const Duration(seconds: 3))
              as List<Object?>? ??
          const [];
    } catch (_) {
      return const [];
    }
    final lang = ttsLanguage.toLowerCase();
    final voices = <Map<String, String>>[];
    for (final v in raw) {
      if (v is! Map) continue;
      final name = v['name'];
      final locale = v['locale'];
      if (name is! String || locale is! String) continue;
      if (locale.toLowerCase().replaceAll('_', '-') != lang) continue;
      // Android: 인터넷이 필요하거나 음성 데이터가 없는 음성
      if (v['network_required'] == '1') continue;
      final features = v['features'];
      if (features is String && features.split('\t').contains('notInstalled')) {
        continue;
      }
      // Google TTS의 "ko-KR-language"는 기본 음성을 가리키는 별칭이라 겹친다
      if (name.toLowerCase() == '$lang-language') continue;
      voices.add({'name': name, 'locale': locale});
    }
    voices.sort((a, b) => a['name']!.compareTo(b['name']!));
    return voices;
  }

  /// 저장해 둔 [name]의 음성을 쓴다. 없어졌으면 엔진 기본 음성 그대로.
  static Future<void> apply(
    FlutterTts tts,
    String ttsLanguage,
    String? name,
  ) async {
    if (name == null) return;
    final voices = await installed(tts, ttsLanguage);
    final voice = voices.where((v) => v['name'] == name).firstOrNull;
    if (voice != null) await tts.setVoice(voice);
  }
}
