import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// 앱 아이콘: 덤벨 + 타이머 링 (2026-11-19).
///
/// - 배경: 어두운 바탕에 코랄·앰버·인디고 빛 번짐 (docs/04 2장 팔레트)
/// - 전경: 3/4 채워진 흰 타이머 링, 그 안에 유리 원판과 비스듬한 흰 덤벨
///
/// 아이콘 PNG 생성(`tool/generate_app_icon_test.dart`)과 앱 화면(결제·결과)에서 함께 쓴다.
/// Android 적응형 아이콘은 배경과 전경을 나눠 그린다. 전경은 가운데 66% 안전 영역 안에 둔다.
class AppIconPainter extends CustomPainter {
  const AppIconPainter({
    this.background = true,
    this.foreground = true,
    this.ringProgress = 0.75,
  });

  final bool background;
  final bool foreground;

  /// 타이머 링이 채워진 비율
  final double ringProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    if (background) _paintBackground(canvas, s);
    if (foreground) _paintForeground(canvas, s);
    canvas.restore();
  }

  void _paintBackground(Canvas canvas, double s) {
    final rect = Rect.fromLTWH(0, 0, s, s);
    canvas.drawRect(rect, Paint()..color = AppColors.bgBase);
    void glow(Color c, Alignment center, double radius) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: center,
            radius: radius,
            colors: [c, c.withValues(alpha: 0)],
          ).createShader(rect),
      );
    }

    glow(
      PhaseColors.work.c1.withValues(alpha: 0.95),
      const Alignment(-0.75, -0.8),
      0.95,
    );
    glow(
      PhaseColors.work.c2.withValues(alpha: 0.70),
      const Alignment(0.85, 0.9),
      0.85,
    );
    glow(
      PhaseColors.setRest.c1.withValues(alpha: 0.60),
      const Alignment(0.95, -0.75),
      0.7,
    );
  }

  void _paintForeground(Canvas canvas, double s) {
    final c = Offset(s / 2, s / 2);

    // 타이머 링 (트랙 + 진행)
    final ringR = s * 0.285;
    final ringW = s * 0.046;
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringW
        ..color = Colors.white.withValues(alpha: 0.20),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: ringR),
      -pi / 2,
      2 * pi * ringProgress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringW
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -pi / 2,
          endAngle: 3 * pi / 2,
          transform: const GradientRotation(-pi / 2),
          colors: [Colors.white.withValues(alpha: 0.75), Colors.white],
        ).createShader(Rect.fromCircle(center: c, radius: ringR)),
    );
    // 링 끝의 작은 점 (시간이 흐르는 느낌)
    final endAngle = -pi / 2 + 2 * pi * ringProgress;
    canvas.drawCircle(
      c + Offset(cos(endAngle), sin(endAngle)) * ringR,
      ringW * 0.32,
      Paint()..color = PhaseColors.work.c1,
    );

    // 유리 원판
    final discR = s * 0.215;
    canvas.drawCircle(
      c,
      discR,
      Paint()..color = Colors.white.withValues(alpha: 0.10),
    );
    canvas.drawCircle(
      c,
      discR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.004
        ..color = Colors.white.withValues(alpha: 0.24),
    );

    // 덤벨 (-35도 기울임)
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-35 * pi / 180);
    final white = Paint()
      ..shader =
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFE3E7F4)],
          ).createShader(
            Rect.fromCenter(
              center: Offset.zero,
              width: s * 0.4,
              height: s * 0.22,
            ),
          );
    final shadow = Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.012);

    RRect bar(double cx, double w, double h, double r) =>
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, 0), width: w, height: h),
          Radius.circular(r),
        );
    final parts = <RRect>[
      bar(0, s * 0.30, s * 0.038, s * 0.019), // 손잡이
      for (final dir in [-1.0, 1.0]) ...[
        bar(dir * s * 0.115, s * 0.052, s * 0.205, s * 0.020), // 안쪽 원판
        bar(dir * s * 0.168, s * 0.040, s * 0.150, s * 0.016), // 바깥 원판
        bar(dir * s * 0.203, s * 0.026, s * 0.050, s * 0.010), // 끝 마개
      ],
    ];
    for (final p in parts) {
      canvas.drawRRect(p.shift(Offset(0, s * 0.012)), shadow);
    }
    for (final p in parts) {
      canvas.drawRRect(p, white);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AppIconPainter old) =>
      old.background != background ||
      old.foreground != foreground ||
      old.ringProgress != ringProgress;
}

/// 앱 안에서 쓰는 아이콘 그림 (모서리 둥근 사각형)
class AppIconMark extends StatelessWidget {
  const AppIconMark({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.23),
    child: SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: AppIconPainter()),
    ),
  );
}
