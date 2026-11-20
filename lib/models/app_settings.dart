// 순수 Dart 모델. Flutter를 import하지 않는다.

/// 음성 속도 (docs/02_기능_명세.md 6.3절)
enum SpeechSpeed {
  slow(0.4),
  normal(0.5),
  fast(0.6);

  const SpeechSpeed(this.ttsRate);

  /// flutter_tts 기준 (Android 보통 속도 0.5)
  final double ttsRate;
}

/// 앱 전체 설정 (docs/02 6.3절, 7장 / docs/03 S5)
class AppSettings {
  const AppSettings({
    this.sound = true,
    this.vibration = true,
    this.voice = true,
    this.countdownSeconds = 3,
    this.speechSpeed = SpeechSpeed.normal,
    this.keepScreenOn = true,
    this.language,
  });

  final bool sound;
  final bool vibration;
  final bool voice;

  /// 0, 3, 5 중 하나
  final int countdownSeconds;
  final SpeechSpeed speechSpeed;

  /// 진행 화면이 열려 있는 동안 화면 꺼짐 방지
  final bool keepScreenOn;

  /// 화면·음성 언어 코드 ("ko", "en"). null이면 기기 언어를 따른다.
  final String? language;

  static const countdownChoices = [0, 3, 5];
  static const languageChoices = ['ko', 'en'];

  AppSettings copyWith({
    bool? sound,
    bool? vibration,
    bool? voice,
    int? countdownSeconds,
    SpeechSpeed? speechSpeed,
    bool? keepScreenOn,
  }) => AppSettings(
    sound: sound ?? this.sound,
    vibration: vibration ?? this.vibration,
    voice: voice ?? this.voice,
    countdownSeconds: countdownSeconds ?? this.countdownSeconds,
    speechSpeed: speechSpeed ?? this.speechSpeed,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    language: language,
  );

  /// [copyWith]로는 null(기기 언어)로 되돌릴 수 없어 따로 둔다
  AppSettings withLanguage(String? language) => AppSettings(
    sound: sound,
    vibration: vibration,
    voice: voice,
    countdownSeconds: countdownSeconds,
    speechSpeed: speechSpeed,
    keepScreenOn: keepScreenOn,
    language: languageChoices.contains(language) ? language : null,
  );

  Map<String, Object?> toJson() => {
    'sound': sound,
    'vibration': vibration,
    'voice': voice,
    'countdownSeconds': countdownSeconds,
    'speechSpeed': speechSpeed.name,
    'keepScreenOn': keepScreenOn,
    'language': language,
  };

  /// 빠지거나 이상한 값은 기본값으로
  factory AppSettings.fromJson(Map<String, Object?> j) {
    const d = AppSettings();
    final cd = (j['countdownSeconds'] as num?)?.toInt();
    return AppSettings(
      sound: j['sound'] as bool? ?? d.sound,
      vibration: j['vibration'] as bool? ?? d.vibration,
      voice: j['voice'] as bool? ?? d.voice,
      countdownSeconds: countdownChoices.contains(cd)
          ? cd!
          : d.countdownSeconds,
      speechSpeed:
          SpeechSpeed.values
              .where((e) => e.name == j['speechSpeed'])
              .firstOrNull ??
          d.speechSpeed,
      keepScreenOn: j['keepScreenOn'] as bool? ?? d.keepScreenOn,
      language: languageChoices.contains(j['language'])
          ? j['language'] as String
          : null,
    );
  }
}
