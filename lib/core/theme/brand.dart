import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// TAMS brand palette, shared by the splash, login and app header so they
/// read as one design.
abstract final class BrandColors {
  static const primary = Color(0xFF2F5BEA);
  static const ink = Color(0xFF0B0F19);
  static const muted = Color(0xFF6B7280);
  static const faint = Color(0xFF9CA3AF);
  static const field = Color(0xFFF3F4F6);
  static const line = Color(0xFFE5E7EB);
  static const error = Color(0xFFDC2626);
  static const errorBg = Color(0xFFFEF2F2);
}

/// Inter at [size], ink-coloured unless [color] is given.
TextStyle brandText(
  double size, {
  FontWeight? weight,
  Color? color,
  double? ls,
}) => GoogleFonts.inter(
  fontSize: size,
  fontWeight: weight,
  color: color ?? BrandColors.ink,
  letterSpacing: ls,
);
