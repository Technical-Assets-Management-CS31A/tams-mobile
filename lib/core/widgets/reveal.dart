import 'package:flutter/widgets.dart';

/// Fades and lifts [child] in during its slice of [parent], starting at
/// [start] (0–1). Stagger several with rising [start]s for an entrance.
class Reveal extends StatelessWidget {
  const Reveal({
    super.key,
    required this.parent,
    required this.start,
    required this.child,
  });

  final Animation<double> parent;
  final double start;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(
      parent: parent,
      curve: Interval(
        start,
        (start + 0.55).clamp(0, 1),
        curve: Curves.easeOutCubic,
      ),
    );
    return FadeTransition(
      opacity: t,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(t),
        child: child,
      ),
    );
  }
}
