import 'package:flutter/material.dart';
import 'tokens.dart';

class AppTheme {
  static ThemeData build(RColors c, Brightness b) {
    final base = ThemeData(brightness: b).textTheme.apply(
      fontFamily: 'InstrumentSans', bodyColor: c.textPrimary, displayColor: c.textPrimary,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      scaffoldBackgroundColor: c.surface0,
      colorScheme: ColorScheme.fromSeed(seedColor: c.fillBrand, brightness: b).copyWith(
        primary: c.fillBrand, onPrimary: c.onFill, surface: c.surface1, error: c.fillDanger,
      ),
      textTheme: base,
      splashFactory: InkRipple.splashFactory,
      dividerColor: c.border,
      extensions: [c],
    );
  }

  static final light = build(RColors.light, Brightness.light);
  static final dark = build(RColors.dark, Brightness.dark);

  /// Editorial display style used for screen titles.
  static TextStyle display(BuildContext context, {double size = 34}) => TextStyle(
        fontFamily: 'InstrumentSans', fontSize: size, fontWeight: FontWeight.w600, letterSpacing: -0.035 * size, height: 1.06,
        color: context.rc.textPrimary,
      );

  static TextStyle mono(BuildContext context, {double size = 12, FontWeight w = FontWeight.w500, Color? color}) =>
      TextStyle(fontFamily: 'JetBrainsMono', fontSize: size, fontWeight: w, color: color ?? context.rc.textMuted);
}
