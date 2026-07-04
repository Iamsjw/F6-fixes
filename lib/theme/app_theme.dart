import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Core Colors ───────────────────────────────────────────────
  static const Color background = Color(0xFF07050F); // Cosmic black/dark violet
  static const Color backgroundVariant = Color(0xFF0D0A1C); // Deep violet space
  static const Color surface = Color(0x13FFFFFF); // Frosted glass (7.4% white)
  static const Color surfaceVariant = Color(0xFF140F26); // Solid premium dark space surface for dialogs and dropdown menus
  static const Color surfaceRaised = Color(0xFF1B1736); // Opaque elevated dark surface

  // ─── Primary & Accent Colors ────────────────────────────────────
  static const Color primary = primaryBlue; // Electric purple
  static const Color primaryBlue = Color(0xFF8B5CF6); // Electric purple/violet
  static const Color primaryCyan = Color(0xFFD946EF); // Neon magenta/pink
  static const Color primaryGreen = Color(0xFF6366F1); // Royal Indigo
  static const Color softGlow = Color(0x22D946EF); // Soft magenta/purple glow

  // ─── Text Colors ─────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF); // Pure white
  static const Color textSecondary = Color(0xFFCECADF); // Lighter muted lilac/gray
  static const Color textMuted = Color(0xFFAEAAC2); // Lighter muted slate purple
  static const Color textDisabled = Color(0xFF88849E); // Light slate for hints/placeholders

  // ─── Status Colors ────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successSoft = Color(0xFF064E3B); // Opaque emerald for high contrast banners
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFF78350F); // Opaque amber for high contrast banners
  static const Color error = Color(0xFFEF4444);
  static const Color errorSoft = Color(0xFF7F1D1D); // Opaque crimson for high contrast error banners

  // ─── Neumorphic Shadows (Rebranded to Glass Shadows) ──────────
  static const Color shadowDark = Color(0x55000000); // Shadow underneath glass
  static const Color shadowLight = Color(0x17FFFFFF); // Glass sheen border

  // ─── Gradients ──────────────────────────────────────────────
  static const Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFD946EF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient surfaceGradient = RadialGradient(
    center: Alignment(-0.6, -0.5),
    radius: 1.4,
    colors: [Color(0x1AD946EF), Colors.transparent],
  );

  // ─── Neumorphic Decorations (Rebranded internally to Glassmorphism)
  static BoxDecoration neumorphic({
    BorderRadiusGeometry? borderRadius,
    bool isRaised = false,
  }) {
    return BoxDecoration(
      color: isRaised ? surfaceRaised : surface,
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      border: Border.all(
        color: const Color(0x18FFFFFF),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF000000).withOpacity(0.35),
          offset: const Offset(0, 8),
          blurRadius: 24,
          spreadRadius: -4,
        ),
      ],
    );
  }

  static BoxDecoration neumorphicGlow({
    BorderRadiusGeometry? borderRadius,
    Color glowColor = primaryCyan,
  }) {
    return BoxDecoration(
      color: surface,
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      border: Border.all(
        color: glowColor.withOpacity(0.28),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF000000).withOpacity(0.35),
          offset: const Offset(0, 8),
          blurRadius: 24,
          spreadRadius: -4,
        ),
        BoxShadow(
          color: glowColor.withOpacity(0.18),
          blurRadius: 24,
          spreadRadius: 2,
        ),
      ],
    );
  }

  // ─── Theme Data ──────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: primaryCyan,
      secondary: primaryBlue,
      surface: surface,
      error: error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimary,
      outline: shadowLight,
    ),
    scaffoldBackgroundColor: background,
    canvasColor: background,
    dialogTheme: const DialogThemeData(
      backgroundColor: surfaceVariant,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shadowColor: Colors.black,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: surfaceVariant,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: surfaceVariant,
      dividerColor: const Color(0x33FFFFFF),
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      TextTheme(
        displayLarge: _buildTextStyle(32, FontWeight.w700, textPrimary, -0.5),
        displayMedium: _buildTextStyle(28, FontWeight.w700, textPrimary, -0.3),
        headlineLarge: _buildTextStyle(24, FontWeight.w700, textPrimary, -0.2),
        headlineMedium: _buildTextStyle(20, FontWeight.w600, textPrimary),
        headlineSmall: _buildTextStyle(18, FontWeight.w600, textPrimary),
        titleLarge: _buildTextStyle(16, FontWeight.w600, textPrimary),
        titleMedium: _buildTextStyle(14, FontWeight.w600, textPrimary),
        titleSmall: _buildTextStyle(13, FontWeight.w600, textSecondary),
        bodyLarge: _buildTextStyle(15, FontWeight.w400, textPrimary),
        bodyMedium: _buildTextStyle(14, FontWeight.w400, textSecondary),
        bodySmall: _buildTextStyle(12, FontWeight.w400, textMuted),
        labelLarge: _buildTextStyle(14, FontWeight.w600, textPrimary, 0.2),
        labelMedium: _buildTextStyle(12, FontWeight.w600, textSecondary, 0.3),
        labelSmall: _buildTextStyle(11, FontWeight.w600, textMuted, 0.4),
      ),
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      iconTheme: const IconThemeData(color: textPrimary),
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: const Color(0xFF130E26).withOpacity(0.65),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0x28FFFFFF), width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0x28FFFFFF), width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryCyan, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: error, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: error, width: 1.5),
      ),
      labelStyle: const TextStyle(color: textMuted, fontSize: 14),
      hintStyle: const TextStyle(color: textDisabled, fontSize: 14),
      errorStyle: const TextStyle(color: error, fontSize: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: primaryBlue.withAlpha(80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: shadowDark,
    ),
    dividerTheme: const DividerThemeData(
      color: shadowLight,
      thickness: 1,
      space: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceVariant,
      selectedColor: primaryBlue.withAlpha(60),
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1E1B2E),
      contentTextStyle: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x33FFFFFF), width: 1),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    iconTheme: const IconThemeData(color: textPrimary, size: 24),
  );

  // lightTheme required by contract - redirect to dark
  static ThemeData get lightTheme => darkTheme;

  // ─── Helper Methods ────────────────────────────────────────────
  static TextStyle _buildTextStyle(
    double fontSize,
    FontWeight fontWeight,
    Color color, [
    double letterSpacing = 0,
  ]) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static BoxDecoration glassMorphism({
    BorderRadiusGeometry? borderRadius,
    double opacity = 0.08,
    Color borderColor = const Color(0x1AFFFFFF),
  }) {
    return BoxDecoration(
      color: Colors.white.withOpacity(opacity),
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.35),
          offset: const Offset(0, 8),
          blurRadius: 24,
          spreadRadius: -4,
        ),
      ],
    );
  }

  // ─── Glow Effect ──────────────────────────────────────────────
  static BoxDecoration glowEffect({
    required Color glowColor,
    BorderRadiusGeometry? borderRadius,
    double intensity = 0.3,
  }) {
    return BoxDecoration(
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: glowColor.withAlpha((intensity * 255).round()),
          blurRadius: 24,
          spreadRadius: 4,
        ),
      ],
    );
  }
}
