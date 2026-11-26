import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../app/app_services.dart';
import '../../design/glass.dart';
import '../../design/tokens.dart';
import '../../models/app_settings.dart';
import '../../models/entitlement.dart';
import '../paywall/paywall_page.dart';
import '../../engine/cue_text.dart';
import '../../l10n/l10n.dart';
import '../../services/app_language.dart';
import '../../services/audio/tts_voices.dart';

/// S5 설정 (docs/03_화면_설계.md 7장). 기능 확인용 기본 UI.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _system = MethodChannel('fitness_timer/system');
  final _tts = FlutterTts();

  /// 고를 수 있는 언어 (AppSettings.languageChoices와 같은 순서)
  static const _languages = [('ko', '한국어'), ('en', 'English')];

  /// 음성 안내 언어 (화면 언어를 따른다)
  CueText? _cueText;

  /// 그 언어의 TTS 음성이 있는지. null = 확인 중
  bool? _voiceAvailable;

  /// 그 언어로 고를 수 있는 기기 음성. 2개 이상일 때만 선택 항목을 보인다.
  List<Map<String, String>> _voices = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final text = CueText.forLanguage(
      Localizations.localeOf(context).languageCode,
    );
    if (text.ttsLanguage != _cueText?.ttsLanguage) {
      _cueText = text;
      _voiceAvailable = null;
      _voices = const [];
      _checkVoice(text.ttsLanguage);
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _checkVoice(String language) async {
    bool ok;
    try {
      ok = await _tts.isLanguageAvailable(language) == true;
    } catch (_) {
      ok = false;
    }
    final voices = ok
        ? await TtsVoices.installed(_tts, language)
        : const <Map<String, String>>[];
    if (mounted) {
      setState(() {
        _voiceAvailable = ok;
        _voices = voices;
      });
    }
  }

  /// 저장된 음성이 목록에 없으면(지워졌거나 다른 엔진) 기본으로 보인다
  String? _voiceName(AppSettings s) {
    final name = s.voices[_cueText?.ttsLanguage];
    return _voices.any((v) => v['name'] == name) ? name : null;
  }

  Future<void> _preview(AppSettings s) async {
    final language = _cueText!.ttsLanguage;
    final text = context.l10n.ttsPreviewText;
    // setLanguage가 엔진 기본 음성으로 되돌린 뒤 고른 음성을 얹는다
    await _tts.setLanguage(language);
    await TtsVoices.apply(_tts, language, _voiceName(s));
    await _tts.setSpeechRate(s.speechSpeed.ttsRate);
    await _tts.speak(text);
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
          appBar: AppBar(title: Text(context.l10n.settings)),
          body: ListView(
            // padding을 직접 주면 ListView가 하단 시스템 바 높이를 더해 주지 않는다.
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              56 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              _Group(context.l10n.language),
              _Card(
                children: [
                  ListTile(
                    title: Text(context.l10n.language),
                    trailing: DropdownButton<String?>(
                      value: s.language,
                      underline: const SizedBox.shrink(),
                      onChanged: (v) => AppLanguage.set(store, v),
                      items: [
                        DropdownMenuItem(
                          child: Text(context.l10n.languageSystem),
                        ),
                        // 언어 이름은 그 언어로 쓴다
                        for (final (code, name) in _languages)
                          DropdownMenuItem(value: code, child: Text(name)),
                      ],
                    ),
                  ),
                ],
              ),
              _Group(context.l10n.alerts),
              _Card(
                children: [
                  SwitchListTile(
                    title: Text(context.l10n.sound),
                    value: s.sound,
                    onChanged: (v) => set(s.copyWith(sound: v)),
                  ),
                  SwitchListTile(
                    title: Text(context.l10n.vibration),
                    value: s.vibration,
                    onChanged: (v) => set(s.copyWith(vibration: v)),
                  ),
                  SwitchListTile(
                    title: Text(context.l10n.voiceGuide),
                    value: s.voice,
                    onChanged: (v) => set(s.copyWith(voice: v)),
                  ),
                  // 제목 아래에 선택 버튼 (좁은 화면에서 제목이 끊기지 않게)
                  ListTile(
                    title: Text(context.l10n.countdownBeforeEnd),
                    subtitle: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: 0,
                              label: Text(context.l10n.none),
                            ),
                            ButtonSegment(
                              value: 3,
                              label: Text(context.l10n.durationSeconds(3)),
                            ),
                            ButtonSegment(
                              value: 5,
                              label: Text(context.l10n.durationSeconds(5)),
                            ),
                          ],
                          selected: {s.countdownSeconds},
                          onSelectionChanged: (v) =>
                              set(s.copyWith(countdownSeconds: v.first)),
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    title: Text(context.l10n.speechSpeed),
                    subtitle: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SegmentedButton<SpeechSpeed>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: SpeechSpeed.slow,
                              label: Text(context.l10n.speedSlow),
                            ),
                            ButtonSegment(
                              value: SpeechSpeed.normal,
                              label: Text(context.l10n.speedNormal),
                            ),
                            ButtonSegment(
                              value: SpeechSpeed.fast,
                              label: Text(context.l10n.speedFast),
                            ),
                          ],
                          selected: {s.speechSpeed},
                          onSelectionChanged: (v) =>
                              set(s.copyWith(speechSpeed: v.first)),
                        ),
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: context.l10n.previewVoice,
                      icon: const Icon(Icons.volume_up_outlined),
                      onPressed: _voiceAvailable == true
                          ? () => _preview(s)
                          : null,
                    ),
                  ),
                  if (_voices.length >= 2)
                    ListTile(
                      title: Text(context.l10n.voiceChoice),
                      trailing: DropdownButton<String?>(
                        value: _voiceName(s),
                        underline: const SizedBox.shrink(),
                        onChanged: (v) {
                          final next = s.withVoice(_cueText!.ttsLanguage, v);
                          set(next);
                          _preview(next);
                        },
                        items: [
                          DropdownMenuItem(
                            child: Text(context.l10n.voiceDefault),
                          ),
                          // 엔진의 음성 이름("ko-kr-x-ism-local")은 읽기 어려워 번호로 보인다
                          for (final (i, v) in _voices.indexed)
                            DropdownMenuItem(
                              value: v['name'],
                              child: Text(context.l10n.voiceNumber(i + 1)),
                            ),
                        ],
                      ),
                    ),
                  ListTile(
                    title: Text(context.l10n.voiceData),
                    subtitle: Text(switch (_voiceAvailable) {
                      null => context.l10n.checking,
                      true => context.l10n.available,
                      false => context.l10n.voiceMissing,
                    }),
                    trailing: _voiceAvailable == false
                        ? TextButton(
                            onPressed: _openTtsSettings,
                            child: Text(context.l10n.openTtsSettings),
                          )
                        : null,
                  ),
                ],
              ),
              _Group(context.l10n.screen),
              _Card(
                children: [
                  SwitchListTile(
                    title: Text(context.l10n.keepScreenOn),
                    value: s.keepScreenOn,
                    onChanged: (v) => set(s.copyWith(keepScreenOn: v)),
                  ),
                ],
              ),
              _Group(context.l10n.other),
              _Card(
                children: [
                  ListTile(
                    title: Text(context.l10n.openSourceLicenses),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Fitness Timer',
                    ),
                  ),
                ],
              ),
              const _PurchaseSection(),
            ],
          ),
        );
      },
    );
  }
}

/// 설정 화면의 "정식 버전" 묶음 (docs/03 7장) + 디버그 빌드 전용 테스트 도구
class _PurchaseSection extends StatelessWidget {
  const _PurchaseSection();

  @override
  Widget build(BuildContext context) {
    final ent = AppServices.entitlement;
    return ListenableBuilder(
      listenable: Listenable.merge([ent, AppServices.billing]),
      builder: (context, _) {
        final e = ent.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Group(context.l10n.fullVersion),
            _Card(
              children: [
                ListTile(
                  title: Text(context.l10n.status),
                  subtitle: Text(
                    e.isFull
                        ? context.l10n.fullVersionActive
                        : e.inTrial
                        ? context.l10n.freeRemaining(e.freeRemaining)
                        : context.l10n.trialEnded,
                  ),
                ),
                if (!e.isFull)
                  ListTile(
                    title: Text(context.l10n.buyFullVersion),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => PaywallPage.open(context),
                  ),
                ListTile(
                  title: Text(context.l10n.restorePurchase),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final l10n = context.l10n;
                    await AppServices.billing.restore();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          ent.value.isFull
                              ? l10n.purchaseRestored
                              : l10n.noPurchaseToRestore,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            if (kDebugMode) ...[
              const _Group('개발용 (디버그 빌드에서만 보임)'),
              _Card(
                children: [
                  SwitchListTile(
                    title: const Text('결제 없이 정식 버전으로 보기'),
                    value: ent.debugForceFull,
                    onChanged: ent.setDebugForceFull,
                  ),
                  ListTile(
                    title: Text(
                      '무료 운동 사용 횟수: ${e.freeUsed} / ${Entitlement.freeWorkouts}',
                    ),
                    subtitle: Wrap(
                      spacing: 8,
                      children: [
                        for (final n in [0, 10, 14, 15])
                          ActionChip(
                            label: Text('$n회로'),
                            onPressed: () => ent.setDebugFreeUsed(n),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
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
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

/// 설정 묶음 카드 (약한 유리, 블러 없음)
class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => GlassPanel(
    level: GlassLevel.subtle,
    radius: 20,
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(children: children),
  );
}
