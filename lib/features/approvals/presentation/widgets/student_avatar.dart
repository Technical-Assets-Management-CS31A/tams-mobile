import 'package:flutter/material.dart';

/// Student's photo, or their initials when there is no photo or it fails
/// to load.
class StudentAvatar extends StatelessWidget {
  const StudentAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 24,
  });

  final String name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final url = photoUrl;

    return Semantics(
      label: 'Photo of $name',
      image: true,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: colors.secondaryContainer,
        foregroundColor: colors.onSecondaryContainer,
        // Initials stay underneath, so they show while loading or on error.
        foregroundImage: url == null ? null : NetworkImage(url),
        onForegroundImageError: url == null ? null : (_, _) {},
        child: Text(
          initials(name),
          style: TextStyle(fontSize: radius * 0.7, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// "Maria Santos" -> "MS", "Cher" -> "C".
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}
