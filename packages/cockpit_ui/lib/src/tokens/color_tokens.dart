import 'package:flutter/material.dart';

/// The three global **color controls** — primary, secondary, tertiary — plus a
/// small set of derived semantic colors.
///
/// This is the single source of truth for brand color. Change [brand] (or push
/// new values via the theme controller / backend RemoteConfig) to re-skin the
/// entire app. Widgets must read colors from the [ColorScheme] built off these
/// tokens, never hard-code a hex value.
@immutable
class CockpitColors {
  const CockpitColors({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;

  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  /// Default Octopilot brand palette — a **black / red / warm-white** identity.
  /// Red is the single accent; surfaces are near-black (dark) or warm off-white
  /// (light); text is a soft, yellow-hued white. The exact surface/onSurface
  /// values are applied per-brightness in [CockpitTheme].
  static const CockpitColors brand = CockpitColors(
    primary: Color(0xFFE11D2E), // signal red
    secondary: Color(0xFFF04E3E), // warm coral-red
    tertiary: Color(0xFFE8B84B), // warm gold (the soft-yellow accent)
    success: Color(0xFF3FB27F),
    warning: Color(0xFFE8B84B),
    error: Color(0xFFFF6B5C),
    info: Color(0xFF5B8DEF),
  );

  CockpitColors copyWith({
    Color? primary,
    Color? secondary,
    Color? tertiary,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
  }) {
    return CockpitColors(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      tertiary: tertiary ?? this.tertiary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
    );
  }
}
