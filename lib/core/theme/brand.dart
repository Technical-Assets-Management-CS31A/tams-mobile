import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// TAMS brand palette, shared by the splash, login, app header and audit
/// screens so they read as one design.
abstract final class BrandColors {
  static const primary = Color(0xFF2F5BEA);
  static const ink = Color(0xFF0B0F19);
  static const muted = Color(0xFF6B7280);
  static const faint = Color(0xFF9CA3AF);
  static const field = Color(0xFFF3F4F6);
  static const line = Color(0xFFE5E7EB);
  static const error = Color(0xFFDC2626);
  static const errorBg = Color(0xFFFEF2F2);
  static const success = Color(0xFF15803D);
  static const successBg = Color(0xFFF0FDF4);
  static const warning = Color(0xFFB45309);
  static const warningBg = Color(0xFFFFFBEB);
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

/// Button looks matching the login screen: flat, rounded, Inter labels.
abstract final class BrandButtons {
  static RoundedRectangleBorder _shape(double radius) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

  /// Solid brand-blue button for the main action.
  static ButtonStyle primary({double height = 44, double radius = 12}) =>
      FilledButton.styleFrom(
        backgroundColor: BrandColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: BrandColors.field,
        disabledForegroundColor: BrandColors.faint,
        elevation: 0,
        minimumSize: Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: _shape(radius),
        textStyle: brandText(14, weight: FontWeight.w600),
      );

  /// Grey-filled button for secondary actions.
  static ButtonStyle subtle({double height = 44, double radius = 12}) =>
      TextButton.styleFrom(
        backgroundColor: BrandColors.field,
        foregroundColor: BrandColors.ink,
        disabledBackgroundColor: BrandColors.field.withValues(alpha: 0.6),
        disabledForegroundColor: BrandColors.faint,
        minimumSize: Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: _shape(radius),
        textStyle: brandText(14, weight: FontWeight.w600),
      );

  /// Compact text-only button in [color], for actions inside a banner.
  static ButtonStyle inline(Color color) => TextButton.styleFrom(
    foregroundColor: color,
    disabledForegroundColor: color.withValues(alpha: 0.4),
    minimumSize: const Size(0, 36),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    shape: _shape(10),
    textStyle: brandText(13, weight: FontWeight.w600),
  );

  /// Red-outlined button for destructive actions.
  static ButtonStyle danger({double height = 44, double radius = 12}) =>
      OutlinedButton.styleFrom(
        foregroundColor: BrandColors.error,
        side: BorderSide(color: BrandColors.error.withValues(alpha: 0.4)),
        minimumSize: Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: _shape(radius),
        textStyle: brandText(14, weight: FontWeight.w600),
      );
}

/// Small rounded label, such as "In progress", in the header's pill style.
class BrandPill extends StatelessWidget {
  const BrandPill(
    this.text, {
    super.key,
    this.color = BrandColors.primary,
    this.background,
    this.icon,
  });

  final String text;
  final Color color;

  /// Defaults to [color] at 10% opacity.
  final Color? background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: brandText(12, weight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
