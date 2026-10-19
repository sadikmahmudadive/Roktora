import 'package:flutter/material.dart';

/// Role-based color tokens ported from the Roktora design system.
@immutable
class RColors extends ThemeExtension<RColors> {
  const RColors({
    required this.surface0, required this.surface1, required this.surface2, required this.surface3,
    required this.textPrimary, required this.textSecondary, required this.textMuted, required this.textDisabled,
    required this.textAccent, required this.textDanger, required this.textSuccess, required this.textWarning, required this.textBrand,
    required this.border, required this.borderStrong, required this.borderStronger,
    required this.borderAccent, required this.borderDanger, required this.borderSuccess, required this.borderWarning,
    required this.fillPrimary, required this.fillAccent, required this.fillDanger, required this.fillSuccess, required this.fillWarning, required this.fillBrand,
    required this.onFill, required this.onPrimary,
    required this.bgAccent, required this.bgDanger, required this.bgSuccess, required this.bgWarning, required this.bgBrand,
    required this.progressTrack, required this.hover, required this.glass,
    required this.mapBlock, required this.mapRoad,
  });

  final Color surface0, surface1, surface2, surface3;
  final Color textPrimary, textSecondary, textMuted, textDisabled;
  final Color textAccent, textDanger, textSuccess, textWarning, textBrand;
  final Color border, borderStrong, borderStronger;
  final Color borderAccent, borderDanger, borderSuccess, borderWarning;
  final Color fillPrimary, fillAccent, fillDanger, fillSuccess, fillWarning, fillBrand;
  final Color onFill, onPrimary;
  final Color bgAccent, bgDanger, bgSuccess, bgWarning, bgBrand;
  final Color progressTrack, hover, glass;
  final Color mapBlock, mapRoad;

  static const light = RColors(
    surface0: Color(0xFFF3F2EF), surface1: Color(0xFFFFFFFF), surface2: Color(0xFFEAE8E3), surface3: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF141413), textSecondary: Color(0xFF55534D), textMuted: Color(0xFF76736C), textDisabled: Color(0xFFB3B0A8),
    textAccent: Color(0xFF1D5FBF), textDanger: Color(0xFFB3261E), textSuccess: Color(0xFF1B6B3C), textWarning: Color(0xFF7F4C00), textBrand: Color(0xFFB01A30),
    border: Color(0x1A141413), borderStrong: Color(0x33141413), borderStronger: Color(0x66141413),
    borderAccent: Color(0xFF2F6FD1), borderDanger: Color(0xFFC8321F), borderSuccess: Color(0xFF2B8A4B), borderWarning: Color(0xFFC98A12),
    fillPrimary: Color(0xFF141413), fillAccent: Color(0xFF2F6FD1), fillDanger: Color(0xFFC8321F), fillSuccess: Color(0xFF22995A), fillWarning: Color(0xFFB97C0C), fillBrand: Color(0xFFD42A40),
    onFill: Color(0xFFFFFFFF), onPrimary: Color(0xFFF7F6F3),
    bgAccent: Color(0xFFE6EEFB), bgDanger: Color(0xFFFCE9E6), bgSuccess: Color(0xFFE2F3E8), bgWarning: Color(0xFFFCF0D8), bgBrand: Color(0xFFFDE8EA),
    progressTrack: Color(0x14141413), hover: Color(0x0A141413), glass: Color(0xC7F3F2EF),
    mapBlock: Color(0xFFF3F1EC), mapRoad: Color(0xFFE6E3DC),
  );

  static const dark = RColors(
    surface0: Color(0xFF121211), surface1: Color(0xFF1D1C1B), surface2: Color(0xFF282725), surface3: Color(0xFF323130),
    textPrimary: Color(0xFFF4F2EC), textSecondary: Color(0xFFC2BFB7), textMuted: Color(0xFF9A978F), textDisabled: Color(0xFF5F5D58),
    textAccent: Color(0xFF8FB5F3), textDanger: Color(0xFFF2A093), textSuccess: Color(0xFF8DD3A5), textWarning: Color(0xFFECC679), textBrand: Color(0xFFFF9AA7),
    border: Color(0x17FFFFFF), borderStrong: Color(0x2EFFFFFF), borderStronger: Color(0x5CFFFFFF),
    borderAccent: Color(0xFF5B92E6), borderDanger: Color(0xFFE0614E), borderSuccess: Color(0xFF4AA86A), borderWarning: Color(0xFFD69B2A),
    fillPrimary: Color(0xFFF4F2EC), fillAccent: Color(0xFF3D7DDB), fillDanger: Color(0xFFCF4632), fillSuccess: Color(0xFF2F9F5F), fillWarning: Color(0xFFB57F14), fillBrand: Color(0xFFE5384E),
    onFill: Color(0xFFFFFFFF), onPrimary: Color(0xFF121211),
    bgAccent: Color(0xFF1B2740), bgDanger: Color(0xFF3A1F1B), bgSuccess: Color(0xFF18301F), bgWarning: Color(0xFF382C15), bgBrand: Color(0xFF3B171D),
    progressTrack: Color(0x1AFFFFFF), hover: Color(0x0DFFFFFF), glass: Color(0xBF121211),
    mapBlock: Color(0xFF282724), mapRoad: Color(0xFF33322E),
  );

  @override
  RColors copyWith() => this;

  @override
  RColors lerp(ThemeExtension<RColors>? other, double t) {
    if (other is! RColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension RThemeX on BuildContext {
  RColors get rc => Theme.of(this).extension<RColors>()!;
}

class RRadius {
  static const double base = 14;
  static const double card = 24;
  static const double tile = 18;
  static const double pill = 999;
}
