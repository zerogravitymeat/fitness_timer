/// 루틴 이름 자동완성 검색. 화면과 분리해 단위 테스트한다.
///
/// - 부분 일치: `스쿼` → 스쿼트, 점프 스쿼트
/// - 초성: `ㅅㅋㅌ` → 스쿼트. 초성과 완성 글자를 섞어도 된다 (`스ㅋ`).
/// - 입력 중인 마지막 글자: `레그 커` → 레그 컬, `풋` → 푸시업 (ㅅ이 받침으로 붙은 상태)
/// - 띄어쓰기, 하이픈, 영문 대소문자는 무시한다 (`pushup` → Push-up).
abstract final class NameSearch {
  /// [query]에 맞는 이름을 최대 [limit]개.
  /// 앞부분이 맞는 것 → 중간이 맞는 것 순이고, 같은 순위에서는
  /// [mine](내 루틴 이름)이 [common](운동 목록)보다 먼저, 그 안에서는 넘겨준 순서대로.
  /// 입력과 완전히 같은 이름은 고를 필요가 없으므로 뺀다.
  static List<String> search(
    String query, {
    required List<String> mine,
    required List<String> common,
    int limit = 8,
  }) {
    final q = _norm(query);
    if (q.isEmpty) return const [];
    final seen = <String>{};
    final front = <String>[], middle = <String>[];
    for (final name in [...mine, ...common]) {
      final n = _norm(name);
      if (name == query.trim() || !seen.add(n)) continue;
      final pos = matchPosition(q, n);
      if (pos == 0) {
        front.add(name);
      } else if (pos > 0) {
        middle.add(name);
      }
    }
    return [...front, ...middle].take(limit).toList();
  }

  static String _norm(String s) =>
      s.replaceAll(RegExp(r'[\s\-]+'), '').toLowerCase();

  /// 정규화된 [q]가 [name] 안에서 처음 맞는 위치. 없으면 -1.
  static int matchPosition(String q, String name) {
    final qs = q.runes.toList(), ns = name.runes.toList();
    for (var start = 0; start + qs.length <= ns.length; start++) {
      if (_matchesAt(qs, ns, start)) return start;
    }
    return -1;
  }

  static bool _matchesAt(List<int> qs, List<int> ns, int start) {
    for (var i = 0; i < qs.length; i++) {
      final qc = qs[i], nc = ns[start + i];
      if (qc == nc) continue;
      if (_isChoseongJamo(qc) && _isSyllable(nc) && _choseongJamo(nc) == qc) {
        continue;
      }
      if (i == qs.length - 1 && _partialLast(qc, nc, ns, start + i + 1)) {
        continue;
      }
      return false;
    }
    return true;
  }

  /// 아직 다 치지 않은 마지막 글자 [qc]가 이름의 [nc]와 맞는지
  static bool _partialLast(int qc, int nc, List<int> ns, int next) {
    if (!_isSyllable(qc) || !_isSyllable(nc)) return false;
    final q = qc - _base, n = nc - _base;
    final qCho = q ~/ 588, qJung = (q % 588) ~/ 28, qJong = q % 28;
    final nCho = n ~/ 588, nJung = (n % 588) ~/ 28, nJong = n % 28;
    if (qCho != nCho) return false;
    // `커` → 컬, `쿠` → 쿼 (겹모음을 치는 중)
    if (qJong == 0) {
      return qJung == nJung || _vowelPrefix[qJung]?.contains(nJung) == true;
    }
    // `풋` → 푸시: 다음 글자의 초성이 받침으로 잠시 붙은 상태
    if (qJung != nJung || nJong != 0 || next >= ns.length) return false;
    final cho = _jongToCho[qJong];
    return cho != null &&
        _isSyllable(ns[next]) &&
        (ns[next] - _base) ~/ 588 == cho;
  }

  static const _base = 0xAC00;
  static bool _isSyllable(int c) => c >= _base && c <= 0xD7A3;

  // 호환 자모 초성 19개 (ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ)
  static const _choseong = [
    0x3131, 0x3132, 0x3134, 0x3137, 0x3138, 0x3139, 0x3141, 0x3142, 0x3143, //
    0x3145, 0x3146, 0x3147, 0x3148, 0x3149, 0x314A, 0x314B, 0x314C, 0x314D,
    0x314E,
  ];
  static bool _isChoseongJamo(int c) => _choseong.contains(c);
  static int _choseongJamo(int syllable) =>
      _choseong[(syllable - _base) ~/ 588];

  /// 중성 번호 → 그 모음 뒤에 한 타를 더 쳐서 될 수 있는 겹모음
  /// (ㅗ→ㅘㅙㅚ, ㅜ→ㅝㅞㅟ, ㅡ→ㅢ)
  static const _vowelPrefix = {
    8: {9, 10, 11},
    13: {14, 15, 16},
    18: {19},
  };

  /// 홑받침 번호 → 같은 자음의 초성 번호
  static const _jongToCho = {
    1: 0, 2: 1, 4: 2, 7: 3, 8: 5, 16: 6, 17: 7, 19: 9, 20: 10, //
    21: 11, 22: 12, 23: 14, 24: 15, 25: 16, 26: 17, 27: 18,
  };
}
