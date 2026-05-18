import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yama design tokens — Stitch design system.
///
/// `AppColors` exposes both **light** (default static getters) and **dark**
/// (`AppColors.dark`) palettes. Most app code should read colors from
/// `Theme.of(context).colorScheme` so dark mode "just works"; the static
/// helpers here are for legacy call sites and decorations that need fixed
/// chrome tones.
class AppColors {
  // ── LIGHT ──────────────────────────────────────────────────────────────
  static const primary = Color(0xFF154212);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF2D5A27);
  static const onPrimaryContainer = Color(0xFF9DD090);
  static const primaryFixed = Color(0xFFBCF0AE);
  static const primaryFixedDim = Color(0xFFA1D494);
  static const onPrimaryFixed = Color(0xFF002201);
  static const onPrimaryFixedVariant = Color(0xFF23501E);

  static const secondary = Color(0xFF6D5B50);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFF7DECF);
  static const onSecondaryContainer = Color(0xFF736155);

  static const tertiary = Color(0xFF2F3E00);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFF435700);
  static const onTertiaryContainer = Color(0xFFAFCE5C);
  static const tertiaryFixed = Color(0xFFCFEF78);
  static const tertiaryFixedDim = Color(0xFFB3D25F);

  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

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

  static const chrome = Color(0xFFF2F0EA);
  static const chromeBorder = Color(0xFFD6D3C6);

  // Difficulty pills (light)
  static const difficultyEasyBg = Color(0xFFBCF0AE);
  static const difficultyEasyFg = Color(0xFF23501E);
  static const difficultyModerateBg = Color(0xFFF7DECF);
  static const difficultyModerateFg = Color(0xFF93420C);
  static const difficultyHardBg = Color(0xFF435700);
  static const difficultyHardFg = Color(0xFFAFCE5C);

  /// Dark-mode palette. Mirrors the standard Material 3 dark scheme paired
  /// against the same Forest Green brand color.
  static const dark = _DarkPalette();
}

class _DarkPalette {
  const _DarkPalette();

  // Primary stays the same Forest Green family but inverted: bright moss-green
  // surfaces on near-black background.
  final Color primary = const Color(0xFFA1D494);
  final Color onPrimary = const Color(0xFF003908);
  final Color primaryContainer = const Color(0xFF23501E);
  final Color onPrimaryContainer = const Color(0xFFBCF0AE);

  final Color secondary = const Color(0xFFDAC2B4);
  final Color onSecondary = const Color(0xFF3D2D24);
  final Color secondaryContainer = const Color(0xFF544339);
  final Color onSecondaryContainer = const Color(0xFFF7DECF);

  final Color tertiary = const Color(0xFFB3D25F);
  final Color onTertiary = const Color(0xFF263500);
  final Color tertiaryContainer = const Color(0xFF3B4D00);
  final Color onTertiaryContainer = const Color(0xFFCFEF78);

  final Color error = const Color(0xFFFFB4AB);
  final Color onError = const Color(0xFF690005);
  final Color errorContainer = const Color(0xFF93000A);
  final Color onErrorContainer = const Color(0xFFFFDAD6);

  final Color surface = const Color(0xFF0F1518);
  final Color surfaceContainerLowest = const Color(0xFF0A0F12);
  final Color surfaceContainerLow = const Color(0xFF161D20);
  final Color surfaceContainer = const Color(0xFF1A2225);
  final Color surfaceContainerHigh = const Color(0xFF252D30);
  final Color surfaceContainerHighest = const Color(0xFF30383B);
  final Color onSurface = const Color(0xFFE0E4E1);
  final Color onSurfaceVariant = const Color(0xFFC2C9BB);
  final Color outline = const Color(0xFF8C9387);
  final Color outlineVariant = const Color(0xFF42493E);
  final Color inverseSurface = const Color(0xFFE0E4E1);
  final Color inverseOnSurface = const Color(0xFF2A3138);
  final Color inversePrimary = const Color(0xFF154212);
  final Color background = const Color(0xFF0F1518);
  final Color onBackground = const Color(0xFFE0E4E1);

  // Chrome stays dark, with a subtle border for separation.
  final Color chrome = const Color(0xFF0A0F12);
  final Color chromeBorder = const Color(0xFF2A3138);

  // Difficulty pills in dark mode use the same hues but on lower-luminosity
  // backgrounds so they read as colored tags against the dark surface.
  final Color difficultyEasyBg = const Color(0xFF23501E);
  final Color difficultyEasyFg = const Color(0xFFBCF0AE);
  final Color difficultyModerateBg = const Color(0xFF544339);
  final Color difficultyModerateFg = const Color(0xFFF7DECF);
  final Color difficultyHardBg = const Color(0xFF3B4D00);
  final Color difficultyHardFg = const Color(0xFFCFEF78);
}

class AppSpacing {
  static const double base = 8;
  static const double marginMobile = 20;
  static const double gutter = 16;
  static const double stackSm = 12;
  static const double stackMd = 24;
  static const double stackLg = 40;
  static const double touchTarget = 48;
}

class AppRadius {
  static const double sm = 4;
  static const double base = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

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

/// Singleton notifier for app theme. The value is rebroadcast through
/// `ValueListenableBuilder` in the app root so every rebuild picks up changes.
class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _key = 'theme_mode';

  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.dark);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    mode.value = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  Future<void> set(ThemeMode m) async {
    mode.value = m;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, switch (m) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }
}

// ─── Theme builders ──────────────────────────────────────────────────────

ThemeData buildAppTheme() => _buildTheme(Brightness.light);
ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final p = AppColors.dark;

  final scheme = isDark
      ? ColorScheme.dark(
          primary: p.primary,
          onPrimary: p.onPrimary,
          primaryContainer: p.primaryContainer,
          onPrimaryContainer: p.onPrimaryContainer,
          secondary: p.secondary,
          onSecondary: p.onSecondary,
          secondaryContainer: p.secondaryContainer,
          onSecondaryContainer: p.onSecondaryContainer,
          tertiary: p.tertiary,
          onTertiary: p.onTertiary,
          tertiaryContainer: p.tertiaryContainer,
          onTertiaryContainer: p.onTertiaryContainer,
          error: p.error,
          onError: p.onError,
          errorContainer: p.errorContainer,
          onErrorContainer: p.onErrorContainer,
          surface: p.surface,
          onSurface: p.onSurface,
          surfaceContainerLowest: p.surfaceContainerLowest,
          surfaceContainerLow: p.surfaceContainerLow,
          surfaceContainer: p.surfaceContainer,
          surfaceContainerHigh: p.surfaceContainerHigh,
          surfaceContainerHighest: p.surfaceContainerHighest,
          onSurfaceVariant: p.onSurfaceVariant,
          outline: p.outline,
          outlineVariant: p.outlineVariant,
          inverseSurface: p.inverseSurface,
          onInverseSurface: p.inverseOnSurface,
          inversePrimary: p.inversePrimary,
        )
      : const ColorScheme.light(
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

  final chromeColor = isDark ? p.chrome : AppColors.chrome;
  final chromeBorderColor = isDark ? p.chromeBorder : AppColors.chromeBorder;
  final cardColor = isDark ? p.surfaceContainerLow : AppColors.surfaceContainerLowest;

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _SoftFadePageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );

  final textTheme = GoogleFonts.lexendTextTheme(base.textTheme).apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: chromeColor,
      foregroundColor: scheme.primary,
      surfaceTintColor: chromeColor,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      iconTheme: IconThemeData(color: scheme.primary),
      actionsIconTheme: IconThemeData(color: scheme.primary),
      titleTextStyle: GoogleFonts.lexend(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.01 * 20,
        color: scheme.primary,
      ),
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      surfaceTintColor: cardColor,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: scheme.outlineVariant, width: 1),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
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
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
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
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.outlineVariant),
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
        foregroundColor: scheme.primary,
        textStyle: GoogleFonts.lexend(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      hintStyle: GoogleFonts.lexend(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        fontWeight: FontWeight.w400,
      ),
      labelStyle: GoogleFonts.lexend(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: scheme.error),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainer,
      selectedColor: scheme.primary,
      secondarySelectedColor: scheme.primary,
      labelStyle: GoogleFonts.lexend(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      secondaryLabelStyle: GoogleFonts.lexend(
        color: scheme.onPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: chromeColor,
      selectedItemColor: scheme.primary,
      unselectedItemColor: scheme.onSurfaceVariant,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: chromeColor,
      indicatorColor: scheme.primaryContainer,
      surfaceTintColor: chromeColor,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: scheme.primary);
        }
        return IconThemeData(color: scheme.onSurfaceVariant);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final color = states.contains(WidgetState.selected)
            ? scheme.primary
            : scheme.onSurfaceVariant;
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
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: GoogleFonts.lexend(
        color: scheme.onInverseSurface,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
    extensions: <ThemeExtension<dynamic>>[
      AppChromeColors(
        chrome: chromeColor,
        chromeBorder: chromeBorderColor,
      ),
    ],
  );
}

/// Theme extension carrying chrome (top bar / bottom bar) tokens, which
/// don't have direct equivalents in `ColorScheme`.
class AppChromeColors extends ThemeExtension<AppChromeColors> {
  final Color chrome;
  final Color chromeBorder;
  const AppChromeColors({required this.chrome, required this.chromeBorder});

  @override
  AppChromeColors copyWith({Color? chrome, Color? chromeBorder}) =>
      AppChromeColors(
        chrome: chrome ?? this.chrome,
        chromeBorder: chromeBorder ?? this.chromeBorder,
      );

  @override
  AppChromeColors lerp(ThemeExtension<AppChromeColors>? other, double t) {
    if (other is! AppChromeColors) return this;
    return AppChromeColors(
      chrome: Color.lerp(chrome, other.chrome, t)!,
      chromeBorder: Color.lerp(chromeBorder, other.chromeBorder, t)!,
    );
  }

  static AppChromeColors of(BuildContext context) =>
      Theme.of(context).extension<AppChromeColors>() ??
      const AppChromeColors(
          chrome: AppColors.chrome, chromeBorder: AppColors.chromeBorder);
}

/// Softer, shorter page transitions for Android — feels closer to iOS spring.
class _SoftFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _SoftFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }
}

// ── Decoration helpers ──────────────────────────────────────────────────

BoxDecoration topoCardDecoration(BuildContext context,
    {double radius = AppRadius.md}) {
  final scheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: scheme.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: scheme.outlineVariant),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

BoxDecoration sunkenFieldDecoration(BuildContext context,
    {double radius = AppRadius.md}) {
  final scheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: scheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: scheme.outlineVariant),
  );
}

/// Difficulty pill colors keyed off the trail difficulty label.
({Color bg, Color fg}) difficultyColors(BuildContext context, String difficulty) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final p = AppColors.dark;
  switch (difficulty.toLowerCase()) {
    case 'easy':
      return isDark
          ? (bg: p.difficultyEasyBg, fg: p.difficultyEasyFg)
          : (bg: AppColors.difficultyEasyBg, fg: AppColors.difficultyEasyFg);
    case 'moderate':
      return isDark
          ? (bg: p.difficultyModerateBg, fg: p.difficultyModerateFg)
          : (bg: AppColors.difficultyModerateBg, fg: AppColors.difficultyModerateFg);
    case 'hard':
    case 'challenging':
    case 'expert':
      return isDark
          ? (bg: p.difficultyHardBg, fg: p.difficultyHardFg)
          : (bg: AppColors.difficultyHardBg, fg: AppColors.difficultyHardFg);
    default:
      final scheme = Theme.of(context).colorScheme;
      return (bg: scheme.surfaceContainerHigh, fg: scheme.onSurfaceVariant);
  }
}
