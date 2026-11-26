import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// 반투명 유리 패널 (docs/04 3장).
///
/// [blur]는 진행 화면처럼 패널 수가 적은 곳에서만 켠다. `BackdropFilter`는
/// 저사양 Android에서 무겁고, 스크롤 목록에서는 쓰지 않는다 (docs/04 3장 성능).
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.level = GlassLevel.regular,
    this.radius = AppRadius.panel,
    this.padding = const EdgeInsets.all(16),
    this.blur = false,
  });

  final Widget child;
  final GlassLevel level;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        color: Colors.white.withValues(alpha: level.fill),
        border: Border.all(color: Colors.white.withValues(alpha: level.border)),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (!blur) return box;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 32,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        // CSS blur 24px ≈ Flutter sigma 12 (docs/04 3장)
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: box,
        ),
      ),
    );
  }
}

class PhaseColorsTween extends Tween<PhaseColors> {
  PhaseColorsTween({super.begin, super.end});
  @override
  PhaseColors lerp(double t) => PhaseColors.lerp(begin!, end!, t);
}

/// 진행 화면 배경: 어두운 바탕 + 구간 색 두 개가 번지는 빛 (docs/04 2.3절).
/// 구간이 바뀌면 600ms 동안 서서히 바뀐다.
class PhaseBackground extends StatelessWidget {
  const PhaseBackground({super.key, required this.colors, required this.child});

  final PhaseColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<PhaseColors>(
      tween: PhaseColorsTween(end: colors),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, c, child) => _Glow(
        spots: [
          _Spot(
            c.c1.withValues(alpha: 0.88),
            const Alignment(-0.8, -0.85),
            1.15,
          ),
          _Spot(c.c2.withValues(alpha: 0.78), const Alignment(0.9, 0.4), 1.15),
        ],
        child: child!,
      ),
      child: child,
    );
  }
}

/// 홈·편집·설정 등의 배경: 같은 바탕에 인디고·코랄·민트를 약하게 (docs/04 2.4절)
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => _Glow(
    spots: [
      _Spot(
        PhaseColors.setRest.c1.withValues(alpha: 0.42),
        const Alignment(-1, -1),
        1.0,
      ),
      _Spot(
        PhaseColors.work.c1.withValues(alpha: 0.30),
        const Alignment(1, -0.1),
        0.9,
      ),
      _Spot(
        PhaseColors.rest.c1.withValues(alpha: 0.26),
        const Alignment(-0.8, 1),
        0.9,
      ),
    ],
    child: child,
  );
}

/// 완료 화면 배경: 운동·휴식·세트 간 휴식 색을 함께 (docs/04 2.2절 Aurora)
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => _Glow(
    spots: [
      _Spot(
        PhaseColors.work.c1.withValues(alpha: 0.75),
        const Alignment(-0.9, -0.85),
        1.0,
      ),
      _Spot(
        PhaseColors.setRest.c1.withValues(alpha: 0.70),
        const Alignment(0.95, -0.4),
        0.95,
      ),
      _Spot(
        PhaseColors.rest.c1.withValues(alpha: 0.65),
        const Alignment(-0.2, 1.05),
        1.0,
      ),
    ],
    child: child,
  );
}

class _Spot {
  const _Spot(this.color, this.center, this.radius);
  final Color color;
  final Alignment center;
  final double radius;
}

class _Glow extends StatelessWidget {
  const _Glow({required this.spots, required this.child});
  final List<_Spot> spots;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(color: AppColors.bgBase),
    child: Stack(
      fit: StackFit.expand,
      children: [
        for (final s in spots)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: s.center,
                radius: s.radius,
                colors: [s.color, s.color.withValues(alpha: 0)],
              ),
            ),
          ),
        child,
      ],
    ),
  );
}

/// 큰 버튼. [primary]는 거의 불투명한 흰색 (docs/04 1장 원칙 4), 나머지는 유리.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.glowColor,
    this.height = 76,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  /// 주요 버튼 아래 은은한 빛 (구간 색)
  final Color? glowColor;

  /// null이면 부모 높이를 채운다 (가로 배치)
  final double? height;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(AppRadius.button);
    final fg = primary ? const Color(0xFF14161F) : Colors.white;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          color: primary
              ? Colors.white.withValues(alpha: 0.92)
              : Colors.white.withValues(alpha: 0.12),
          border: Border.all(
            color: Colors.white.withValues(alpha: primary ? 0.9 : 0.22),
          ),
          boxShadow: primary && glowColor != null
              ? [
                  BoxShadow(
                    color: glowColor!.withValues(alpha: 0.35),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: r,
            onTap: onPressed,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg, size: primary ? 28 : 24),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: primary ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 구간 이름 알약 (강한 유리)
class GlassPill extends StatelessWidget {
  const GlassPill({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: Colors.white.withValues(alpha: GlassLevel.strong.fill),
      border: Border.all(
        color: Colors.white.withValues(alpha: GlassLevel.strong.border),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
        child: child,
      ),
    ),
  );
}
