import 'package:material_ui/material_ui.dart';

/// The web dashboard's three base colors and its sRGB surface mixes.
class StudioColors extends ThemeExtension<StudioColors> {
  const StudioColors(this.ground, this.ink, this.accent, this.brightness);

  static const dark = StudioColors(Color(0xFF1D1F23), Color(0xFFEEE8DC), Color(0xFFF2A65A), Brightness.dark);
  static const light = StudioColors(Color(0xFFF4EDE0), Color(0xFF14213D), Color(0xFFFF6B5B), Brightness.light);

  static StudioColors of(BuildContext context) => Theme.of(context).extension<StudioColors>() ?? dark;

  final Color ground;
  final Color ink;
  final Color accent;
  final Brightness brightness;

  Color get sheet => Color.lerp(ground, ink, .05)!;
  Color get wash => Color.lerp(ground, ink, .09)!;
  Color get rule => Color.lerp(ground, ink, .12)!;
  Color get ruleStrong => Color.lerp(ground, ink, .24)!;
  Color get sub => Color.lerp(ground, ink, .62)!;
  Color get accentSoft => Color.lerp(ground, accent, .16)!;
  Color get accentText => brightness == Brightness.dark ? accent : Color.lerp(ink, accent, .45)!;
  Color get onAccent => brightness == Brightness.dark ? ground : ink;
  Color get ok => ink;
  Color get hy => accentText;
  Color get no => accentText;
  Color get flagBg => Color.lerp(ground, accent, .08)!;
  Color get markBg => accent.withValues(alpha: .14);
  Color get authBackground => ground;
  Color get authInk => ink;
  Color get authSub => sub;
  Color get authRule => ruleStrong;
  Color get authError => accentText;
  Color get authButtonText => ground;

  @override
  StudioColors copyWith({Color? ground, Color? ink, Color? accent, Brightness? brightness}) =>
      StudioColors(ground ?? this.ground, ink ?? this.ink, accent ?? this.accent, brightness ?? this.brightness);

  @override
  StudioColors lerp(covariant StudioColors? other, double t) => other == null
      ? this
      : StudioColors(
          Color.lerp(ground, other.ground, t)!,
          Color.lerp(ink, other.ink, t)!,
          Color.lerp(accent, other.accent, t)!,
          t < .5 ? brightness : other.brightness,
        );
}

const fontFallback = ['Pretendard', 'Apple SD Gothic Neo', 'Malgun Gothic', 'Noto Sans KR'];
const studioCard = BorderRadius.all(Radius.circular(18));
const studioControl = BorderRadius.all(Radius.circular(10));

ThemeData studioTheme([Brightness brightness = Brightness.dark]) {
  final c = brightness == Brightness.dark ? StudioColors.dark : StudioColors.light;
  final base = ThemeData(brightness: brightness, useMaterial3: true, fontFamily: 'Pretendard');
  final shape = RoundedRectangleBorder(borderRadius: studioControl);
  return base.copyWith(
    extensions: [c],
    scaffoldBackgroundColor: c.ground,
    canvasColor: c.ground,
    dividerColor: c.rule,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.ink,
      onPrimary: c.ground,
      primaryContainer: c.wash,
      onPrimaryContainer: c.ink,
      secondary: c.accent,
      onSecondary: c.onAccent,
      secondaryContainer: c.accentSoft,
      onSecondaryContainer: c.ink,
      tertiary: c.ink,
      onTertiary: c.ground,
      error: c.accentText,
      onError: c.ground,
      surface: c.sheet,
      surfaceContainer: c.sheet,
      surfaceContainerHighest: c.wash,
      onSurface: c.ink,
      onSurfaceVariant: c.sub,
      outline: c.ruleStrong,
      outlineVariant: c.rule,
      surfaceTint: Colors.transparent,
      shadow: c.ink.withValues(alpha: .26),
      scrim: c.ink.withValues(alpha: .30),
    ),
    textTheme: base.textTheme
        .copyWith(
          headlineLarge: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -.8),
          headlineSmall: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          titleMedium: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          bodyMedium: const TextStyle(fontSize: 15, height: 1.5),
          bodySmall: const TextStyle(fontSize: 13, height: 1.45),
        )
        .apply(bodyColor: c.ink, displayColor: c.ink, fontFamilyFallback: fontFallback),
    appBarTheme: AppBarTheme(
      backgroundColor: c.ground,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: c.sheet,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: studioCard),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.ink,
        foregroundColor: c.ground,
        minimumSize: const Size(0, 40),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        side: BorderSide(color: c.ruleStrong),
        minimumSize: const Size(0, 40),
        shape: shape,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.sheet,
      border: OutlineInputBorder(
        borderRadius: studioControl,
        borderSide: BorderSide(color: c.rule),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: studioControl,
        borderSide: BorderSide(color: c.accent),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.ink,
      selectionColor: c.accentSoft,
      selectionHandleColor: c.accent,
    ),
  );
}
