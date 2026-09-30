import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const backgroundBase = Color(0xFFFFF9FC);
  static const pinkMist = Color(0xFFFCE8F3);
  static const lavenderMist = Color(0xFFEEE8FF);
  static const softPurple = Color(0xFFDCCBFF);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF241B20);
  static const mutedInk = Color(0xFF6F6268);
  static const rose = Color(0xFFD85A8A);
  static const lumiBlue = Color(0xFF70B8F5);
  static const lumiPurple = Color(0xFFAD8AF5);
  static const lumiPink = Color(0xFFFF8DB8);
  static const lumiPeach = Color(0xFFFFC889);
  static const paleRose = Color(0xFFF9DCE9);
  static const plum = Color(0xFF6C3657);
  static const deepPlum = Color(0xFF43243A);
  static const blushPink = Color(0xFFFFE1EC);
  static const softRose = Color(0xFFF8DDE7);
  static const softPink = Color(0xFFFFF0F6);
  static const softViolet = Color(0xFFE9DFFF);
  static const peachPink = Color(0xFFFFE7DE);
  static const lilac = Color(0xFFE5D9FF);
  static const success = Color(0xFF28785A);
  static const warning = Color(0xFF9A641D);
  static const error = Color(0xFFB3261E);
  static const line = Color(0xFFEBDDE5);
  static const focus = Color(0xFF8358B8);

  // Compatibility aliases while the remaining screens migrate to semantic names.
  static const ivory = backgroundBase;
  static const paper = surface;
}

class AdminColors {
  const AdminColors._();

  static const deepPlum = Color(0xFF3F2136);
  static const sidebarPlum = Color(0xFF4B2940);
  static const primaryPurple = Color(0xFF7251B5);
  static const lavender = Color(0xFFB9A7E8);
  static const softLavender = Color(0xFFEEE9FA);
  static const lumiPink = Color(0xFFE85C94);
  static const softPink = Color(0xFFFCE7F0);
  static const background = Color(0xFFF6F4F8);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE7E2EA);
  static const textPrimary = Color(0xFF2C2530);
  static const textSecondary = Color(0xFF746D78);
  static const success = Color(0xFF2E9D68);
  static const warning = Color(0xFFE7A33D);
  static const danger = Color(0xFFD95361);
  static const info = Color(0xFF4B8FD8);
  static const aiAccent = Color(0xFF7C5AC7);
  static const dataQuality = Color(0xFFA86CC1);
  static const tableHover = Color(0xFFF7F3FC);
}

class AppGradients {
  const AppGradients._();

  static const ambient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF0E8FF), Color(0xFFFFEEF6), Color(0xFFFFFAFC)],
  );

  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.plum, AppColors.rose],
  );

  static const brandHeader = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.lumiBlue,
      AppColors.lumiPurple,
      AppColors.lumiPink,
      AppColors.lumiPeach,
    ],
  );

  static const flashSale = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFE91E63), Color(0xFF8E24AA)],
  );

  static const heroOverlay = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xE643243A), Color(0xA66C3657), Color(0x1AD85A8A)],
    stops: [0, 0.48, 1],
  );
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
    BoxShadow(color: Color(0x1AD85A8A), blurRadius: 28, offset: Offset(0, 12)),
  ];
  static const lifted = [
    BoxShadow(color: Color(0x296C3657), blurRadius: 34, offset: Offset(0, 16)),
  ];
  static const header = [
    BoxShadow(color: Color(0x146C3657), blurRadius: 24, offset: Offset(0, 6)),
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
