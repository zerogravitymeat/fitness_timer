import 'package:flutter/material.dart';

import 'tokens.dart';

/// 앱 테마 (docs/04_디자인_가이드.md). MVP는 다크 테마만 (docs/04 2.4절).
/// 배경은 MaterialApp.builder의 [AppBackground]가 그리므로 Scaffold는 투명하다.
abstract final class AppTheme {
  static const fontFamily = 'Pretendard';

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFFC9CFFF),
          onPrimary: const Color(0xFF14161F),
          surface: const Color(0xFF151A28),
          onSurface: AppColors.textBody,
          onSurfaceVariant: AppColors.textSecondary,
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
    );

    // 목록 카드: 블러 없는 약한 유리 (스크롤 성능, docs/04 3장)
    final glassCard = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: Colors.white.withValues(alpha: GlassLevel.subtle.border),
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: const Color(0xFF151A28),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textBody,
        displayColor: AppColors.textBody,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textBody,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: GlassLevel.subtle.fill),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: glassCard,
        margin: const EdgeInsets.symmetric(vertical: 5),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textBody,
        iconColor: AppColors.textSecondary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1A2032),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1A2032),
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.16),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white.withValues(
          alpha: GlassLevel.regular.fill,
        ),
        side: BorderSide(
          color: Colors.white.withValues(alpha: GlassLevel.regular.border),
        ),
        shape: const StadiumBorder(),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
