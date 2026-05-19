import 'package:flutter/material.dart';

/// 应用主题（深色 + 浅色）
class AppTheme {
  AppTheme._();

  static bool _isDarkMode = true;

  // ========== 通用强调色 ==========
  static const Color highlight = Color(0xFF69A6FF);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFE0A94A);
  static const Color error = Color(0xFFE57373);

  // ========== 深色中性色（专业深灰） ==========
  static const Color _darkBackground = Color(0xFF111315);
  static const Color _darkSurface = Color(0xFF181C20);
  static const Color _darkCard = Color(0xFF20252B);
  static const Color _darkAccent = Color(0xFF2A3038);
  static const Color _darkTextPrimary = Color(0xFFF3F4F6);
  static const Color _darkTextSecondary = Color(0xFF9AA4B2);
  static const Color _darkBorder = Color(0xFF313841);

  // ========== 浅色中性色 ==========
  static const Color _lightBackground = Color(0xFFF4F6F8);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightCard = Color(0xFFFFFFFF);
  static const Color _lightAccent = Color(0xFFE8EEF6);
  static const Color _lightTextPrimary = Color(0xFF1F2933);
  static const Color _lightTextSecondary = Color(0xFF6B7280);
  static const Color _lightBorder = Color(0xFFD7DEE7);

  static bool get isDarkMode => _isDarkMode;

  static Color get background =>
      _isDarkMode ? _darkBackground : _lightBackground;
  static Color get surface => _isDarkMode ? _darkSurface : _lightSurface;
  static Color get card => _isDarkMode ? _darkCard : _lightCard;
  static Color get accent => _isDarkMode ? _darkAccent : _lightAccent;
  static Color get textPrimary =>
      _isDarkMode ? _darkTextPrimary : _lightTextPrimary;
  static Color get textSecondary =>
      _isDarkMode ? _darkTextSecondary : _lightTextSecondary;
  static Color get border => _isDarkMode ? _darkBorder : _lightBorder;

  static void syncThemeMode(String themeMode) {
    _isDarkMode = themeMode != 'light';
  }

  static ThemeData get darkTheme => _buildTheme(
    brightness: Brightness.dark,
    background: _darkBackground,
    surface: _darkSurface,
    card: _darkCard,
    accent: _darkAccent,
    textPrimary: _darkTextPrimary,
    textSecondary: _darkTextSecondary,
    border: _darkBorder,
  );

  static ThemeData get lightTheme => _buildTheme(
    brightness: Brightness.light,
    background: _lightBackground,
    surface: _lightSurface,
    card: _lightCard,
    accent: _lightAccent,
    textPrimary: _lightTextPrimary,
    textSecondary: _lightTextSecondary,
    border: _lightBorder,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color card,
    required Color accent,
    required Color textPrimary,
    required Color textSecondary,
    required Color border,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: highlight,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: textPrimary,
      error: error,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
    );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      cardColor: card,
      dividerColor: border,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: ThemeData(
        brightness: brightness,
      ).textTheme.apply(bodyColor: textPrimary, displayColor: textPrimary),
      cardTheme: CardThemeData(
        color: card,
        elevation: isDark ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border, width: 0.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: highlight,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: highlight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: textPrimary),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: highlight,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: highlight),
        ),
        hintStyle: TextStyle(color: textSecondary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: highlight,
        linearTrackColor: border,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 0.5),
      chipTheme: ChipThemeData(
        backgroundColor: accent,
        labelStyle: TextStyle(color: textPrimary, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: border.withValues(alpha: 0.75)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border, width: 0.5),
        ),
        textStyle: TextStyle(color: textPrimary, fontSize: 13),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStatePropertyAll(BorderSide(color: border, width: 0.5)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        textStyle: TextStyle(color: textPrimary),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262B31) : const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: highlight,
        selectionColor: highlight.withValues(alpha: 0.28),
        selectionHandleColor: highlight,
      ),
    );
  }
}
