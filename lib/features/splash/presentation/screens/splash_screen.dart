import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/brand.dart';
import '../../../../core/widgets/brand_logo.dart';

/// Shown at launch while the saved session is checked. The router moves on
/// to /login or the tabs by itself once the app is ready.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  late final _logo = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
  );
  late final _logoFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0, 0.4, curve: Curves.easeOut),
  );
  late final _title = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
  );
  late final _footer = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.55, 1, curve: Curves.easeOut),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_intro.isAnimating || _intro.isCompleted) return;
    // Skip the entrance when the user has turned animations off.
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        // Same white as the native launch screen, so the handoff is seamless.
        backgroundColor: Colors.white,
        // Fills the screen: Scaffold's body constraints are loose, so a bare
        // Column would shrink to its content and hug the left edge.
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Centered on the whole screen, not the space above the footer.
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.8, end: 1.0).animate(_logo),
                      child: const BrandLogo(size: 96),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _title,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(_title),
                      child: Text(
                        'TAMS',
                        style: GoogleFonts.inter(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                          color: BrandColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: FadeTransition(
                    opacity: _footer,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: BrandColors.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'ACLC College of Mandaue',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: BrandColors.faint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
