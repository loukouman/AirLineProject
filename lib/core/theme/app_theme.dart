import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFFC45A1C);
  static const primaryDark = Color(0xFFA94D18);
  static const headerBg = Color(0xFFD6CDC4);
  static const textDark = Color(0xFF3A2A22);
  static const textSoft = Color(0xFF7A6A5F);
  static const appBg = Color(0xFFFAF7F4);

  // Alias conservés pour compatibilité avec le reste du code existant
  static const skyDeep = primary;
  static const skyMid = primaryDark;
  static const skyPale = Color(0xFFF3E6DC);
  static const coral = primary;
  static const coralSoft = Color(0xFFF3E6DC);
  static const ink = textDark;
  static const inkSoft = textSoft;
  static const success = Color(0xFF2E9E6B);
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.appBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.headerBg,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
    );
  }
}
