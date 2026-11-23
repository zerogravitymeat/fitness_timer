import 'package:fitness_timer/services/audio/tts_voices.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  final setVoice = <Object?>[];

  Map<String, String> voice(
    String name,
    String locale, {
    bool network = false,
    String features = '',
  }) => {
    'name': name,
    'locale': locale,
    'network_required': network ? '1' : '0',
    'features': features,
  };

  setUp(() {
    setVoice.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getVoices':
              return [
                voice('ko-kr-x-kod-local', 'ko-KR'),
                voice('ko-kr-x-ism-local', 'ko-KR'),
                voice('ko-kr-x-ism-network', 'ko-KR', network: true),
                voice(
                  'ko-kr-x-kob-local',
                  'ko-KR',
                  features: 'networkTimeoutMs\tnotInstalled',
                ),
                voice('ko-KR-language', 'ko-KR'),
                voice('en-us-x-iol-local', 'en-US'),
              ];
            case 'setVoice':
              setVoice.add(call.arguments);
              return 1;
          }
          return null;
        });
  });

  test('그 언어의 설치된 기기 안 음성만, 이름 순', () async {
    final voices = await TtsVoices.installed(FlutterTts(), 'ko-KR');
    expect(voices.map((v) => v['name']), [
      'ko-kr-x-ism-local',
      'ko-kr-x-kod-local',
    ]);
  });

  test('저장된 음성이 있을 때만 setVoice', () async {
    final tts = FlutterTts();
    await TtsVoices.apply(tts, 'ko-KR', null);
    await TtsVoices.apply(tts, 'ko-KR', 'ko-kr-x-gone-local');
    expect(setVoice, isEmpty);
    await TtsVoices.apply(tts, 'ko-KR', 'ko-kr-x-kod-local');
    expect(setVoice, [
      {'name': 'ko-kr-x-kod-local', 'locale': 'ko-KR'},
    ]);
  });
}
