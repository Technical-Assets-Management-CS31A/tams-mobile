import 'package:flutter/material.dart';

import '../theme/brand.dart';

/// White app bar in the shell header's style: a grey rounded back button,
/// an Inter title with an optional [subtitle], and a hairline under it.
PreferredSizeWidget brandAppBar(
  BuildContext context, {
  required String title,
  String? subtitle,
  List<Widget> actions = const [],
}) {
  final canPop = Navigator.of(context).canPop();
  return AppBar(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    elevation: 0,
    toolbarHeight: 64,
    automaticallyImplyLeading: false,
    titleSpacing: canPop ? 4 : 20,
    shape: const Border(bottom: BorderSide(color: BrandColors.line)),
    leading: canPop
        ? Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Center(
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).maybePop(),
                style: IconButton.styleFrom(
                  backgroundColor: BrandColors.field,
                  foregroundColor: BrandColors.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
            ),
          )
        : null,
    leadingWidth: canPop ? 64 : null,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: brandText(18, weight: FontWeight.w700, ls: -0.4),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: brandText(13, color: BrandColors.muted),
          ),
      ],
    ),
    actions: actions,
  );
}
