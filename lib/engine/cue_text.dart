import 'korean_speech.dart';

/// 음성 안내 문구 (docs/02_기능_명세.md 6장). 언어마다 하나씩 구현한다.
/// [CuePlanner]는 이 조각들을 ", "로 이어 한 문장으로 읽는다.
abstract interface class CueText {
  /// 기기 언어 코드에 맞는 문구. 지원하지 않으면 영어.
  static CueText forLanguage(String languageCode) => switch (languageCode) {
    'ko' => const KoreanCueText(),
    _ => const EnglishCueText(),
  };

  /// TTS 엔진에 넘길 언어 (예: "ko-KR")
  String get ttsLanguage;

  String get prepare;
  String get workStart;
  String setLabel(int set);
  String roundLabel(int round);
  String setDone(int set);
  String rest(int ms);

  /// 횟수 모드에서 곧 할 세트. [round]가 null이면 세트가 하나뿐.
  String reps(int? round, int reps);

  /// 휴식 안내 끝에 붙는 다음 세트 안내
  String nextReps(String reps);
  String nextRoutine(String name);

  String countdown(int seconds);
  String get halfway;
  String get tenSecondsLeft;
  String get down;
  String get up;
  String repNumber(int n);
  String get stopped;
  String completed(int totalMs);
}

class KoreanCueText implements CueText {
  const KoreanCueText();

  @override
  String get ttsLanguage => 'ko-KR';
  @override
  String get prepare => '준비하세요';
  @override
  String get workStart => '운동 시작';
  @override
  String setLabel(int set) => '$set세트';
  @override
  String roundLabel(int round) => '$round라운드';
  @override
  String setDone(int set) => '$set세트 완료';
  @override
  String rest(int ms) => '휴식 ${KoreanSpeech.duration(ms)}';
  @override
  String reps(int? round, int reps) =>
      round == null ? '$reps회' : '$round세트 $reps회';
  @override
  String nextReps(String reps) => '다음 $reps';
  // 조사 문제가 없도록 "다음은 + 이름" 순서로
  @override
  String nextRoutine(String name) => '다음은 $name';
  @override
  String countdown(int seconds) => '$seconds';
  @override
  String get halfway => '절반 지났습니다';
  @override
  String get tenSecondsLeft => '10초 남았습니다';
  @override
  String get down => '내려가고';
  @override
  String get up => '올라오고';
  // TTS가 "1"을 "일"로 읽으므로 고유어 수사로 바꿔 넣는다
  @override
  String repNumber(int n) => KoreanSpeech.nativeNumber(n);
  @override
  String get stopped => '운동 종료';
  @override
  String completed(int totalMs) => '운동 완료. 총 ${KoreanSpeech.duration(totalMs)}';
}

class EnglishCueText implements CueText {
  const EnglishCueText();

  @override
  String get ttsLanguage => 'en-US';
  @override
  String get prepare => 'Get ready';
  @override
  String get workStart => 'Go';
  @override
  String setLabel(int set) => 'Set $set';
  @override
  String roundLabel(int round) => 'Round $round';
  @override
  String setDone(int set) => 'Set $set done';
  @override
  String rest(int ms) => 'Rest ${_duration(ms)}';
  @override
  String reps(int? round, int reps) {
    final count = reps == 1 ? '1 rep' : '$reps reps';
    return round == null ? count : 'Set $round, $count';
  }

  @override
  String nextReps(String reps) => 'Next, $reps';
  @override
  String nextRoutine(String name) => 'Next up, $name';
  @override
  String countdown(int seconds) => '$seconds';
  @override
  String get halfway => 'Halfway there';
  @override
  String get tenSecondsLeft => '10 seconds left';
  @override
  String get down => 'Down';
  @override
  String get up => 'Up';
  // 영어 TTS는 숫자를 그대로 자연스럽게 읽는다
  @override
  String repNumber(int n) => '$n';
  @override
  String get stopped => 'Workout ended';
  @override
  String completed(int totalMs) =>
      'Workout complete. Total ${_duration(totalMs)}';

  /// 90000 → "1 minute 30 seconds". 초 미만은 버림.
  static String _duration(int ms) {
    final total = ms ~/ 1000;
    final m = total ~/ 60, s = total % 60;
    String unit(int n, String one) => n == 1 ? '1 $one' : '$n ${one}s';
    if (m == 0) return unit(s, 'second');
    if (s == 0) return unit(m, 'minute');
    return '${unit(m, 'minute')} ${unit(s, 'second')}';
  }
}
