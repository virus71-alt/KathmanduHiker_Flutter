import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Kathmandu Hiker design tokens — derived from the Google Stitch design system.
///
/// Brand: "digital equipment" — rugged, tactile, high-legibility outdoor UI.
/// Palette is keyed off Himalayan landscape colors: deep Forest Green primary,
/// Deep Brown secondary, Moss Green tertiary, Alabaster background.
class AppColors {
  // Primary — Forest Green
  static const primary = Color(0xFF154212);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF2D5A27);
  static const onPrimaryContainer = Color(0xFF9DD090);
  static const primaryFixed = Color(0xFFBCF0AE);
  static const primaryFixedDim = Color(0xFFA1D494);
  static const onPrimaryFixed = Color(0xFF002201);
  static const onPrimaryFixedVariant = Color(0xFF23501E);

  // Secondary — Deep Brown
  static const secondary = Color(0xFF6D5B50);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFF7DECF);
  static const onSecondaryContainer = Color(0xFF736155);

  // Tertiary — Moss Green
  static const tertiary = Color(0xFF2F3E00);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFF435700);
  static const onTertiaryContainer = Color(0xFFAFCE5C);
  static const tertiaryFixed = Color(0xFFCFEF78);
  static const tertiaryFixedDim = Color(0xFFB3D25F);

  // Error — Clay red
  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  // Surfaces
  static const surface = Color(0xFFF7F9FF);
  static const surfaceDim = Color(0xFFD4DBE4);
  static const surfaceBright = Color(0xFFF7F9FF);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFEDF4FD);
  static const surfaceContainer = Color(0xFFE8EEF8);
  static const surfaceContainerHigh = Color(0xFFE2E9F2);
  static const surfaceContainerHighest = Color(0xFFDCE3EC);
  static const onSurface = Color(0xFF151C23);
  static const onSurfaceVariant = Color(0xFF42493E);
  static const inverseSurface = Color(0xFF2A3138);
  static const inverseOnSurface = Color(0xFFEBF1FB);
  static const inversePrimary = Color(0xFFA1D494);
  static const outline = Color(0xFF72796E);
  static const outlineVariant = Color(0xFFC2C9BB);
  static const surfaceVariant = Color(0xFFDCE3EC);
  static const background = Color(0xFFF7F9FF);
  static const onBackground = Color(0xFF151C23);

  // Chrome — top app bar / bottom nav alabaster
  static const chrome = Color(0xFFF2F0EA);
  static const chromeBorder = Color(0xFFD6D3C6);

  // Difficulty pill colors
  static const difficultyEasyBg = Color(0xFFE6F2EA);
  static const difficultyEasyFg = Color(0xFF154212);
  static const difficultyModerateBg = Color(0xFFFCE7E1);
  static const difficultyModerateFg = Color(0xFF93420C);
  static const difficultyHardBg = Color(0xFFDCE3EC);
  static const difficultyHardFg = Color(0xFF42493E);
}

/// Stitch spacing scale — 8px base.
class AppSpacing {
  static const double base = 8;
  static const double marginMobile = 20;
  static const double gutter = 16;
  static const double stackSm = 12;
  static const double stackMd = 24;
  static const double stackLg = 40;
  static const double touchTarget = 48;
}

/// Stitch radius scale.
class AppRadius {
  static const double sm = 4;
  static const double base = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// Text styles (Lexend). Use `Theme.of(context).textTheme...` where possible;
/// these helpers expose the Stitch named tokens for hand-styled widgets.
class AppText {
  static TextStyle headlineXl(Color color) => GoogleFonts.lexend(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 48 / 40,
        letterSpacing: -0.02 * 40,
        color: color,
      );

  static TextStyle headlineLg(Color color) => GoogleFonts.lexend(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32,
        letterSpacing: -0.01 * 32,
        color: color,
      );

  static TextStyle headlineMd(Color color) => GoogleFonts.lexend(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        color: color,
      );

  static TextStyle bodyLg(Color color) => GoogleFonts.lexend(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 28 / 18,
        color: color,
      );

  static TextStyle bodyMd(Color color) => GoogleFonts.lexend(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: color,
      );

  static TextStyle labelLg(Color color) => GoogleFonts.lexend(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
        letterSpacing: 0.02 * 14,
        color: color,
      );

  static TextStyle labelSm(Color color) => GoogleFonts.lexend(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.05 * 12,
        color: color,
      );
}

ThemeData buildAppTheme() {
  final scheme = const ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    secondaryContainer: AppColors.secondaryContainer,
    onSecondaryContainer: AppColors.onSecondaryContainer,
    tertiary: AppColors.tertiary,
    onTertiary: AppColors.onTertiary,
    tertiaryContainer: AppColors.tertiaryContainer,
    onTertiaryContainer: AppColors.onTertiaryContainer,
    error: AppColors.error,
    onError: AppColors.onError,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    surfaceContainerLowest: AppColors.surfaceContainerLowest,
    surfaceContainerLow: AppColors.surfaceContainerLow,
    surfaceContainer: AppColors.surfaceContainer,
    surfaceContainerHigh: AppColors.surfaceContainerHigh,
    surfaceContainerHighest: AppColors.surfaceContainerHighest,
    onSurfaceVariant: AppColors.onSurfaceVariant,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
    inverseSurface: AppColors.inverseSurface,
    onInverseSurface: AppColors.inverseOnSurface,
    inversePrimary: AppColors.inversePrimary,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
  );

  final textTheme = GoogleFonts.lexendTextTheme(base.textTheme).apply(
    bodyColor: AppColors.onSurface,
    displayColor: AppColors.onSurface,
  );

  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.chrome,
      foregroundColor: AppColors.primary,
      surfaceTintColor: AppColors.chrome,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withOpacity(0.06),
      iconTheme: const IconThemeData(color: AppColors.primary),
      actionsIconTheme: const IconThemeData(color: AppColors.primary),
      titleTextStyle: GoogleFonts.lexend(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.01 * 20,
        color: AppColors.primary,
      ),
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceContainerLowest,
      surfaceTintColor: AppColors.surfaceContainerLowest,
      shadowColor: Colors.black.withOpacity(0.06),
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.outlineVariant, width: 1),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: GoogleFonts.lexend(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.02 * 14,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: GoogleFonts.lexend(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: GoogleFonts.lexend(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: GoogleFonts.lexend(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      hintStyle: GoogleFonts.lexend(
        color: AppColors.outline,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: GoogleFonts.lexend(
        color: AppColors.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceContainer,
      selectedColor: AppColors.primary,
      secondarySelectedColor: AppColors.primary,
      labelStyle: GoogleFonts.lexend(
        color: AppColors.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      secondaryLabelStyle: GoogleFonts.lexend(
        color: AppColors.onPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      side: const BorderSide(color: AppColors.outlineVariant),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.chrome,
      selectedItemColor: AppColors.primaryContainer,
      unselectedItemColor: AppColors.onSurfaceVariant,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.chrome,
      indicatorColor: AppColors.primaryFixed,
      surfaceTintColor: AppColors.chrome,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.05),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.primary);
        }
        return const IconThemeData(color: AppColors.onSurfaceVariant);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final color = states.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.onSurfaceVariant;
        return GoogleFonts.lexend(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.05 * 11,
          color: color,
        );
      }),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.inverseSurface,
      contentTextStyle: GoogleFonts.lexend(
        color: AppColors.inverseOnSurface,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
  );
}

/// Helper to build the Stitch "Topo-Card" surface — white card with a 1px
/// outline-variant border and a soft ambient shadow. Use for stat cards,
/// trail cards, and grouped form sections.
BoxDecoration topoCardDecoration({double radius = AppRadius.md}) =>
    BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

/// "Sunken field" — the inset look used on search bars and the How-to-Get-There
/// rail. Slight inner shadow on a low-surface container.
BoxDecoration sunkenFieldDecoration({double radius = AppRadius.md}) =>
    BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.outlineVariant),
    );

/// Difficulty pill colors keyed off the trail difficulty label.
({Color bg, Color fg}) difficultyColors(String difficulty) {
  switch (difficulty.toLowerCase()) {
    case 'easy':
      return (bg: AppColors.primaryFixed, fg: AppColors.onPrimaryFixedVariant);
    case 'moderate':
      return (bg: AppColors.secondaryContainer, fg: AppColors.onSecondaryContainer);
    case 'hard':
    case 'challenging':
    case 'expert':
      return (bg: AppColors.tertiaryContainer, fg: AppColors.onTertiaryContainer);
    default:
      return (bg: AppColors.surfaceContainerHigh, fg: AppColors.onSurfaceVariant);
  }
}
