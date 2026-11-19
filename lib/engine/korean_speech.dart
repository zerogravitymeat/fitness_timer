/// 음성 안내 문구용 한국어 표기 (docs/02_기능_명세.md 6.4절)
/// 회차는 고유어 수사("하나, 둘 … 열둘"), 시간은 "1분 30초"로 읽는다.
abstract final class KoreanSpeech {
  static const _ones = ['', '하나', '둘', '셋', '넷', '다섯', '여섯', '일곱', '여덟', '아홉'];
  static const _tens = ['', '열', '스물', '서른', '마흔', '쉰', '예순', '일흔', '여든', '아흔'];

  /// 1~100 고유어 수사. 범위 밖은 숫자 그대로.
  static String nativeNumber(int n) {
    if (n == 100) return '백';
    if (n < 1 || n > 100) return '$n';
    return '${_tens[n ~/ 10]}${_ones[n % 10]}';
  }

  /// 60000 → "1분", 90000 → "1분 30초", 20000 → "20초". 초 미만은 버림.
  static String duration(int ms) {
    final total = ms ~/ 1000;
    final m = total ~/ 60;
    final s = total % 60;
    if (m == 0) return '$s초';
    if (s == 0) return '$m분';
    return '$m분 $s초';
  }
}
