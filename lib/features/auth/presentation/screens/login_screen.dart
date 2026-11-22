import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/theme/brand.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../../core/widgets/reveal.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;

  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
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
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(authControllerProvider.notifier)
        .login(_email.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    // Only Failure messages are written for users.
    final error = !auth.hasError
        ? null
        : auth.error is Failure
        ? (auth.error as Failure).message
        : 'Something went wrong. Please try again.';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          // Fills the screen exactly, so it only scrolls when the keyboard
          // leaves too little room.
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),
                          Reveal(
                            parent: _intro,
                            start: 0,
                            child: const _Brand(),
                          ),
                          const SizedBox(height: 32),
                          const Spacer(),
                          Reveal(
                            parent: _intro,
                            start: 0.1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sign in',
                                  style: brandText(
                                    32,
                                    weight: FontWeight.w700,
                                    ls: -1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Use your school account to borrow and '
                                  'track equipment.',
                                  style: brandText(
                                    15,
                                    color: BrandColors.muted,
                                  ).copyWith(height: 1.45),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          Reveal(
                            parent: _intro,
                            start: 0.2,
                            child: _Field(
                              controller: _email,
                              hint: 'Email',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.next,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Enter your email'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Reveal(
                            parent: _intro,
                            start: 0.28,
                            child: _Field(
                              controller: _password,
                              hint: 'Password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Enter your password'
                                  : null,
                              suffix: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  transitionBuilder: (child, a) =>
                                      ScaleTransition(
                                        scale: a,
                                        child: FadeTransition(
                                          opacity: a,
                                          child: child,
                                        ),
                                      ),
                                  child: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    key: ValueKey(_obscurePassword),
                                    size: 20,
                                    color: BrandColors.faint,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _ErrorBanner(message: error),
                          const SizedBox(height: 24),
                          Reveal(
                            parent: _intro,
                            start: 0.36,
                            child: _PrimaryButton(
                              label: 'Sign in',
                              loading: auth.isLoading,
                              onPressed: _submit,
                            ),
                          ),
                          const Spacer(flex: 2),
                          Reveal(
                            parent: _intro,
                            start: 0.45,
                            child: Text(
                              'ACLC College of Mandaue',
                              textAlign: TextAlign.center,
                              style: brandText(12, color: BrandColors.faint),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const BrandLogo(size: 40),
        const SizedBox(width: 12),
        Text('TAMS', style: brandText(17, weight: FontWeight.w700, ls: -0.3)),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final Widget? suffix;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1.5]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      cursorColor: BrandColors.primary,
      style: brandText(15, weight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: brandText(15, color: BrandColors.faint),
        errorStyle: brandText(12, color: BrandColors.error),
        filled: true,
        fillColor: BrandColors.field,
        prefixIcon: Icon(icon, size: 20, color: BrandColors.faint),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        border: border(Colors.transparent, 0),
        enabledBorder: border(Colors.transparent, 0),
        focusedBorder: border(BrandColors.primary),
        errorBorder: border(BrandColors.error.withValues(alpha: 0.5)),
        focusedErrorBorder: border(BrandColors.error),
      ),
    );
  }
}

/// Slides open when there is a message and closes when it clears.
class _ErrorBanner extends StatelessWidget {
  final String? message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: message == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: ValueKey(message),
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: BrandColors.errorBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: BrandColors.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message!,
                          style: brandText(
                            13,
                            color: BrandColors.error,
                          ).copyWith(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Solid button that dips slightly while pressed and swaps to a spinner
/// while loading.
class _PrimaryButton extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.loading;

    return Listener(
      onPointerDown: enabled ? (_) => _setPressed(true) : null,
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: enabled ? widget.onPressed : null,
            style: FilledButton.styleFrom(
              backgroundColor: BrandColors.primary,
              disabledBackgroundColor: BrandColors.primary.withValues(
                alpha: 0.75,
              ),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: widget.loading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.label,
                      key: const ValueKey('label'),
                      style: brandText(
                        16,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
