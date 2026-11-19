import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../app/app_services.dart';
import '../../models/app_settings.dart';

/// S5 설정 (docs/03_화면_설계.md 7장). 기능 확인용 기본 UI.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _system = MethodChannel('fitness_timer/system');
  final _tts = FlutterTts();

  /// null = 확인 중
  bool? _koreanVoice;

  @override
  void initState() {
    super.initState();
    _checkVoice();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _checkVoice() async {
    bool ok;
    try {
      ok = await _tts.isLanguageAvailable('ko-KR') == true;
    } catch (_) {
      ok = false;
    }
    if (mounted) setState(() => _koreanVoice = ok);
  }

  Future<void> _preview(AppSettings s) async {
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(s.speechSpeed.ttsRate);
    await _tts.speak('휴식 10초 남았습니다');
  }

  Future<void> _openTtsSettings() async {
    try {
      await _system.invokeMethod<bool>('openTtsSettings');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final store = AppServices.settings;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.value;
        void set(AppSettings v) => store.update(v);
        return Scaffold(
          appBar: AppBar(title: const Text('설정')),
          body: ListView(
            children: [
              const _Group('알림'),
              SwitchListTile(
                title: const Text('소리'),
                value: s.sound,
                onChanged: (v) => set(s.copyWith(sound: v)),
              ),
              SwitchListTile(
                title: const Text('진동'),
                value: s.vibration,
                onChanged: (v) => set(s.copyWith(vibration: v)),
              ),
              SwitchListTile(
                title: const Text('음성 안내'),
                value: s.voice,
                onChanged: (v) => set(s.copyWith(voice: v)),
              ),
              ListTile(
                title: const Text('종료 전 카운트다운'),
                trailing: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 0, label: Text('없음')),
                    ButtonSegment(value: 3, label: Text('3초')),
                    ButtonSegment(value: 5, label: Text('5초')),
                  ],
                  selected: {s.countdownSeconds},
                  onSelectionChanged: (v) =>
                      set(s.copyWith(countdownSeconds: v.first)),
                ),
              ),
              ListTile(
                title: const Text('음성 속도'),
                subtitle: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SegmentedButton<SpeechSpeed>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: SpeechSpeed.slow,
                          label: Text('느리게'),
                        ),
                        ButtonSegment(
                          value: SpeechSpeed.normal,
                          label: Text('보통'),
                        ),
                        ButtonSegment(
                          value: SpeechSpeed.fast,
                          label: Text('빠르게'),
                        ),
                      ],
                      selected: {s.speechSpeed},
                      onSelectionChanged: (v) =>
                          set(s.copyWith(speechSpeed: v.first)),
                    ),
                  ),
                ),
                trailing: IconButton(
                  tooltip: '미리 듣기',
                  icon: const Icon(Icons.volume_up_outlined),
                  onPressed: _koreanVoice == true ? () => _preview(s) : null,
                ),
              ),
              ListTile(
                title: const Text('한국어 음성'),
                subtitle: Text(switch (_koreanVoice) {
                  null => '확인 중…',
                  true => '사용 가능',
                  false => '설치 필요. 설치 전에는 비프음과 진동으로만 안내해요.',
                }),
                trailing: _koreanVoice == false
                    ? TextButton(
                        onPressed: _openTtsSettings,
                        child: const Text('TTS 설정 열기'),
                      )
                    : null,
              ),
              const _Group('화면'),
              SwitchListTile(
                title: const Text('운동 중 화면 꺼짐 방지'),
                value: s.keepScreenOn,
                onChanged: (v) => set(s.copyWith(keepScreenOn: v)),
              ),
              const _Group('기타'),
              ListTile(
                title: const Text('오픈소스 라이선스'),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Fitness Timer',
                ),
              ),
              const ListTile(
                title: Text('정식 버전'),
                subtitle: Text('결제 기능을 붙일 때 추가됩니다'),
                enabled: false,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}
