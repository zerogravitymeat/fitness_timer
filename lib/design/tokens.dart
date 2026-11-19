import 'package:flutter/material.dart';

import '../engine/segment.dart';

/// 색상 토큰 (docs/04_디자인_가이드.md 2장)
abstract final class AppColors {
  static const bgBase = Color(0xFF0B0F1A);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textBody = Color(0xFFF4F6FB);
  static const textSecondary = Color(0xFFB7BFD0);
  static const textTertiary = Color(0xFF8E97AB);

  /// 대표 강조색 (인디고)
  static const accent = Color(0xFF6C7CFF);
}

/// 구간 색 한 쌍 (docs/04 2.2절). 단색 대신 가까운 두 색의 그라데이션.
@immutable
class PhaseColors {
  const PhaseColors(this.c1, this.c2);
  final Color c1;
  final Color c2;

  static const prep = PhaseColors(
    Color(0xFFF6B44B),
    Color(0xFFE9795B),
  ); // Honey Amber
  static const work = PhaseColors(
    Color(0xFFFF5D6C),
    Color(0xFFFF8A4C),
  ); // Coral Flame
  static const rest = PhaseColors(
    Color(0xFF2FD3A7),
    Color(0xFF1C9FB8),
  ); // Mint Lagoon
  static const setRest = PhaseColors(
    Color(0xFF6C7CFF),
    Color(0xFF9B6BFF),
  ); // Indigo Dusk
  static const paused = PhaseColors(
    Color(0xFF8A94A6),
    Color(0xFF4B5468),
  ); // Slate Mist

  /// 구간 종류 → 색. 횟수 모드의 휴식은 "세트 간 휴식"이므로 인디고 (docs/02 2.5절)
  static PhaseColors of(
    SegmentType? t, {
    required bool isReps,
    bool paused = false,
  }) {
    if (paused) return PhaseColors.paused;
    return switch (t) {
      SegmentType.prep => prep,
      SegmentType.work => work,
      SegmentType.rest => isReps ? setRest : rest,
      SegmentType.setRest => setRest,
      null => setRest,
    };
  }

  static PhaseColors lerp(PhaseColors a, PhaseColors b, double t) =>
      PhaseColors(Color.lerp(a.c1, b.c1, t)!, Color.lerp(a.c2, b.c2, t)!);

  @override
  bool operator ==(Object other) =>
      other is PhaseColors && other.c1 == c1 && other.c2 == c2;
  @override
  int get hashCode => Object.hash(c1, c2);
}

/// 유리 패널 단계 (docs/04 3장)
enum GlassLevel {
  /// 6% / 14% — 홈 목록 묶음
  subtle(0.06, 0.14),

  /// 10% / 22% — 정보 카드, 보조 버튼
  regular(0.10, 0.22),

  /// 14% / 26% — 구간 이름 알약, +10초
  strong(0.14, 0.26);

  const GlassLevel(this.fill, this.border);
  final double fill;
  final double border;
}

abstract final class AppRadius {
  static const panel = 24.0;
  static const button = 22.0;
  static const small = 14.0;
}

/// 숫자는 고정폭으로 (바뀔 때 폭이 흔들리지 않게, docs/04 4장)
const tabularFigures = [FontFeature.tabularFigures()];
