import 'package:flutter/material.dart';

import '../theme/brand.dart';

/// The round ACLC logo with a hairline border. Falls back to a school icon
/// if the image can't be loaded.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: BrandColors.line),
      ),
      child: ClipOval(
        child: Image.asset(
          'images/aclc_logo.jpeg',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              Icon(Icons.school, color: BrandColors.primary, size: size * 0.46),
        ),
      ),
    );
  }
}
