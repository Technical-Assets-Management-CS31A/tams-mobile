import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/brand.dart';

/// A pushed screen with the shell header's look on top: a grey rounded
/// back button, an Inter title with an optional [subtitle], an optional
/// [trailing] widget such as the connection status, and a hairline under
/// it all.
///
/// Unlike an [AppBar], the header grows to fit, so a long room name wraps
/// onto a second line instead of being cut off.
class BrandPage extends StatelessWidget {
  const BrandPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.trailing,
    this.backgroundColor = Colors.white,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget body;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark status bar icons on the white header.
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Column(
          children: [
            _Header(title: title, subtitle: subtitle, trailing: trailing),
            Expanded(
              // The header already sits below the status bar.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  static const _button = 40.0;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final subtitle = this.subtitle;
    final trailing = this.trailing;
    final titleStyle = brandText(
      17,
      weight: FontWeight.w700,
      ls: -0.3,
    ).copyWith(height: 1.3);
    // Puts the title's first line level with the back button's middle.
    final titleTop = canPop ? (_button - 17 * 1.3) / 2 : 0.0;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: BrandColors.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(canPop ? 12 : 20, 10, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canPop) ...[
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: IconButton.styleFrom(
                    backgroundColor: BrandColors.field,
                    foregroundColor: BrandColors.ink,
                    fixedSize: const Size.square(_button),
                    minimumSize: const Size.square(_button),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: titleTop),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // No line limit: the whole name always shows.
                      Text(title, style: titleStyle),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: brandText(
                            13,
                            color: BrandColors.muted,
                          ).copyWith(height: 1.35),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                Padding(
                  // Level with the title's first line.
                  padding: EdgeInsets.only(top: titleTop + 2),
                  child: trailing,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
