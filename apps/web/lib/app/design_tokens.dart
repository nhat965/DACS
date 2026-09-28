import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const ivory = Color(0xFFFCF9F7);
  static const paper = Color(0xFFFFFFFF);
  static const ink = Color(0xFF241B20);
  static const mutedInk = Color(0xFF6F6268);
  static const rose = Color(0xFFB5486D);
  static const paleRose = Color(0xFFF7E9EE);
  static const plum = Color(0xFF65354C);
  static const success = Color(0xFF28785A);
  static const warning = Color(0xFF9A641D);
  static const line = Color(0xFFE9E1E4);
}

class AppSpacing {
  const AppSpacing._();

  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
  static const section = 64.0;
  static const hero = 80.0;
}

class AppRadius {
  const AppRadius._();

  static const control = 10.0;
  static const card = 16.0;
  static const feature = 24.0;
  static const pill = 999.0;
}

class AppShadows {
  const AppShadows._();

  static const soft = [
    BoxShadow(color: Color(0x14241B20), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const lifted = [
    BoxShadow(color: Color(0x24241B20), blurRadius: 32, offset: Offset(0, 14)),
  ];
}

class AppDurations {
  const AppDurations._();

  static const feedback = Duration(milliseconds: 160);
  static const component = Duration(milliseconds: 240);
  static const section = Duration(milliseconds: 320);
  static const carousel = Duration(seconds: 5);
}

class AppBreakpoints {
  const AppBreakpoints._();

  static const mobile = 600.0;
  static const navigation = 900.0;
  static const desktop = 1200.0;
  static const large = 1440.0;
  static const content = 1280.0;
}

class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(Color color) => TextTheme(
    displayLarge: TextStyle(
      fontSize: 56,
      height: 1.05,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.5,
      color: color,
    ),
    displaySmall: TextStyle(
      fontSize: 38,
      height: 1.12,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.7,
      color: color,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: color,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: color,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: color,
    ),
    bodyLarge: TextStyle(fontSize: 17, height: 1.55, color: color),
    bodyMedium: TextStyle(fontSize: 15, height: 1.5, color: color),
    labelLarge: TextStyle(
      fontSize: 15,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: color,
    ),
  );
}
