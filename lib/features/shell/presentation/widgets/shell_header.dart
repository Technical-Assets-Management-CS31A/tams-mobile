import 'package:flutter/material.dart';

import '../../../../core/theme/brand.dart';
import '../../../../core/widgets/reveal.dart';

/// Top of the signed-in shell, in the login screen's style: the current
/// tab's title with an optional [badge] pill and a short line under it,
/// and a sign-out button beside them.
///
/// Eases in on first show, and the title slides across when the tab
/// changes. Both are skipped when the user has turned animations off.
class ShellHeader extends StatefulWidget {
  const ShellHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSignOut,
    this.badge,
  });

  final String title;
  final String subtitle;
  final VoidCallback onSignOut;

  /// Short status beside the title, such as "2 unread". Hidden when null.
  final String? badge;

  @override
  State<ShellHeader> createState() => _ShellHeaderState();
}

class _ShellHeaderState extends State<ShellHeader>
    with SingleTickerProviderStateMixin {
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_intro.isAnimating || _intro.isCompleted) return;
    if (MediaQuery.of(context).disableAnimations) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: BrandColors.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Reveal(
                  parent: _intro,
                  start: 0,
                  // Centres the title's first line on the sign-out button.
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: AnimatedSwitcher(
                      duration: still
                          ? Duration.zero
                          : const Duration(milliseconds: 360),
                      transitionBuilder: _slideUp,
                      layoutBuilder: _topLeft,
                      child: _Title(
                        key: ValueKey(widget.title),
                        title: widget.title,
                        subtitle: widget.subtitle,
                        badge: widget.badge,
                        still: still,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Reveal(
                parent: _intro,
                start: 0.15,
                child: IconButton(
                  tooltip: 'Sign out',
                  onPressed: widget.onSignOut,
                  style: IconButton.styleFrom(
                    backgroundColor: BrandColors.field,
                    foregroundColor: BrandColors.muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Both titles run this; the old one plays it in reverse. Using only the
  /// second half means the old title is gone before the new one rises in,
  /// so the two never overlap.
  static Widget _slideUp(Widget child, Animation<double> a) {
    final t = CurvedAnimation(
      parent: a,
      curve: const Interval(0.5, 1, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: t,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(t),
        child: child,
      ),
    );
  }
}

/// Keeps outgoing and incoming children left-aligned while they cross.
Widget _topLeft(Widget? current, List<Widget> previous) =>
    Stack(alignment: Alignment.topLeft, children: [...previous, ?current]);

class _Title extends StatelessWidget {
  const _Title({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.still,
  });

  final String title;
  final String subtitle;
  final String? badge;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final badge = this.badge;
    final quick = still ? Duration.zero : const Duration(milliseconds: 200);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: brandText(28, weight: FontWeight.w700, ls: -0.8),
              ),
            ),
            // Pops in and out on its own, so a new count doesn't replay
            // the title's slide.
            AnimatedSwitcher(
              duration: quick,
              transitionBuilder: (child, a) => ScaleTransition(
                scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                child: FadeTransition(opacity: a, child: child),
              ),
              child: badge == null
                  ? const SizedBox.shrink()
                  : Padding(
                      key: ValueKey(badge),
                      padding: const EdgeInsets.only(left: 10),
                      child: _Pill(badge),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: brandText(14, color: BrandColors.muted).copyWith(height: 1.4),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: BrandColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: brandText(
          12,
          weight: FontWeight.w600,
          color: BrandColors.primary,
        ),
      ),
    );
  }
}
