import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// Brand orange
  static const primary = Color(0xFFFF6A00);
  static const primaryDark = Color(0xFFE55A00);
  static const primarySoft = Color(0x33FF6A00);

  /// Deep navy / charcoal (page canvas)
  static const navy = Color(0xFF07111F);
  static const navySoft = Color(0xFF101C30);
  static const navyMuted = Color(0xFF1B2A44);
  static const background = Color(0xFF060E1A);
  static const backgroundMid = Color(0xFF0B1628);

  /// Frosted glass fills
  static const surface = Color(0x1AFFFFFF);
  static const glass = Color(0x14FFFFFF);
  static const glassStrong = Color(0x24FFFFFF);
  static const border = Color(0x33FFFFFF);
  static const borderGlow = Color(0x55FFFFFF);

  /// Text on dark glass
  static const text = Color(0xFFF4F7FB);
  static const muted = Color(0xFF9AA6B8);
  static const placeholder = Color(0xFF7A8699);

  static const wash = Color(0x22FF6A00);
  static const washStrong = Color(0x33FF6A00);

  static const success = Color(0xFF22C55E);
  static const successSoft = Color(0x3322C55E);
  static const danger = Color(0xFFFF4D6D);
  static const dangerSoft = Color(0x33FF4D6D);
  static const warning = Color(0xFFF59E0B);
  static const warningSoft = Color(0x33F59E0B);
  static const info = Color(0xFF38BDF8);
  static const purple = Color(0xFFA78BFA);
  static const purpleSoft = Color(0x33A78BFA);
  static const teal = Color(0xFF2DD4BF);
  static const orange = Color(0xFFFF6A00);
  static const blue = Color(0xFF60A5FA);
  static const blueSoft = Color(0x3360A5FA);
  static const green = Color(0xFF22C55E);
  static const greenSoft = Color(0x3322C55E);

  static const roleSuperAdmin = purple;
  static const roleBusinessAdmin = primary;
  static const roleManager = blue;
  static const roleEmployee = green;

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: primary.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 0),
        ),
      ];

  static List<BoxShadow> get navShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: primary.withValues(alpha: 0.12),
          blurRadius: 20,
          offset: const Offset(0, 0),
        ),
      ];

  static List<BoxShadow> get orangeGlow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.35),
          blurRadius: 22,
          spreadRadius: -2,
        ),
      ];
}
