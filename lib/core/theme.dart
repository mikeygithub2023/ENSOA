import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette "ST Blue" — inspirée d'une référence dashboard bien-être (fond
/// crème, carte sombre de contraste, accents chaleureux) adaptée en bleu :
/// canevas bleu très pâle, grande carte blanche flottante, carte de contraste
/// bleu marine profond, accents en dégradés de bleu.
class AppColors {
  AppColors._();

  // Canevas / structure
  static const Color canvas = Color(0xFFCDD9F0);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color pillBg = Color(0xFFFFFFFF);
  static const Color contrastCard = Color(0xFF101F3C);
  static const Color contrastCardAlt = Color(0xFF162952);

  // Bleus de marque
  static const Color navy = Color(0xFF101F3C);
  static const Color blueDeep = Color(0xFF1E3E8C);
  static const Color blue = Color(0xFF2F6FE0);
  static const Color blueBright = Color(0xFF5B9BFF);
  static const Color blueSoft = Color(0xFFBBD3FF);
  static const Color blueMist = Color(0xFFEAF1FF);

  // Texte
  static const Color ink = Color(0xFF10182B);
  static const Color inkMuted = Color(0xFF6B7690);

  // États (même vocabulaire qu'avant, reteinté)
  static const Color danger = Color(0xFFE0524B);
  static const Color warning = Color(0xFFE0A23B);
  static const Color success = Color(0xFF2FA36B);

  // Legacy aliases (militaire) — conservés pour compat, reteintés en bleu.
  static const Color militaryGreen = blueDeep;
  static const Color militaryGreenLight = blue;
  static const Color gold = Color(0xFFE0A23B);
  static const Color sand = canvas;
  static const Color ivoryOrange = Color(0xFF3D8BFF);

  // Alias employés par les écrans repris de la scolarité — mêmes teintes,
  // autre vocabulaire. Les garder évite de retoucher chaque écran porté.
  static const Color primary = blueDeep;
  static const Color alert = warning;
  static const Color textPrimary = ink;
  static const Color textMuted = inkMuted;
  static const Color border = Color(0xFFE3E9F5);
  static const Color background = canvas;
  static const Color loginPanel = blueDeep;
  static const Color sidebar = navy;
  static const Color header = contrastCardAlt;
  static const Color sidebarTextMuted = Color(0xFF94A3B8);
  static const Color headerTextMuted = blueSoft;
}

class AppRadii {
  AppRadii._();
  static const double shell = 32;
  static const double card = 24;
  static const double pill = 999;
  static const double control = 14;
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.blueDeep,
      brightness: Brightness.light,
      primary: AppColors.blueDeep,
      secondary: AppColors.blue,
      error: AppColors.danger,
      surface: AppColors.cardBg,
    );
    return _themeFrom(scheme, Brightness.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.blueBright,
      brightness: Brightness.dark,
      primary: AppColors.blueBright,
      secondary: AppColors.blueSoft,
      error: const Color(0xFFCF6679),
      surface: const Color(0xFF15213C),
    );
    return _themeFrom(scheme, Brightness.dark);
  }

  static ThemeData _themeFrom(ColorScheme scheme, Brightness brightness) {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? AppColors.canvas
          : const Color(0xFF0B1220),
      textTheme: textTheme.apply(
        bodyColor: brightness == Brightness.light
            ? AppColors.ink
            : Colors.white,
        displayColor: brightness == Brightness.light
            ? AppColors.ink
            : Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(
            color: brightness == Brightness.light
                ? const Color(0xFFE3E9F5)
                : Colors.white24,
            width: 1,
          ),
        ),
        // Volontairement distinct du fond blanc de la grande carte (AppColors.cardBg) :
        // sinon les cartes internes deviennent invisibles, sans séparation visuelle.
        color: brightness == Brightness.light
            ? AppColors.blueMist
            : const Color(0xFF15213C),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          side: BorderSide(color: scheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? AppColors.blueMist
            : Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control + 2),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 22,
        ),
        labelStyle: const TextStyle(fontSize: 15),
        hintStyle: const TextStyle(fontSize: 15),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        side: BorderSide.none,
        backgroundColor: AppColors.blueMist,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
      ),
    );
  }
}

/// États d'alerte réutilisés partout (seuils carburant, révisions, retours d'armes...).
enum AlertLevel { info, warning, critical }

extension AlertLevelColor on AlertLevel {
  Color color(BuildContext context) {
    switch (this) {
      case AlertLevel.info:
        return AppColors.blue;
      case AlertLevel.warning:
        return AppColors.warning;
      case AlertLevel.critical:
        return AppColors.danger;
    }
  }
}

/// Nom sous lequel les écrans repris de la scolarité demandent le thème.
ThemeData buildAppTheme() => AppTheme.light();
