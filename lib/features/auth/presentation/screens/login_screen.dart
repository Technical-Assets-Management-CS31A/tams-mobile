import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/auth_controller.dart';

class _C {
  static const primary = Color(0xFF2F5BEA);
  static const title = Color(0xFF0F172A);
  static const muted = Color(0xFF94A3B8);
  static const hint = Color(0xFFCBD5E1);
  static const fill = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const blob = Color(0xFFF1F5FD);
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(authControllerProvider.notifier)
        .login(_email.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // decorative blobs
          Positioned(top: -40, right: -90, child: _Blob(size: 270)),
          Positioned(bottom: -70, left: -100, child: _Blob(size: 250)),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 72),
                    const Center(child: _Logo()),
                    SizedBox(height: topInset + 72),

                    Text(
                      'Welcome back!',
                      style: GoogleFonts.poppins(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                        color: _C.title,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Access the Technical Equipment Borrowing System.',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        height: 1.5,
                        color: _C.muted,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // EMAIL
                    const _Label('EMAIL'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      style: GoogleFonts.poppins(color: _C.title),
                      decoration: _inputDecoration('you@aclc.edu.ph'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter your email'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // PASSWORD
                    const _Label('PASSWORD'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      style: GoogleFonts.poppins(color: _C.title),
                      decoration: _inputDecoration(
                        'Enter your password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: _C.muted,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Enter your password'
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 20),

                    if (auth.hasError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${auth.error}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),

                    // Sign In button
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _C.primary.withOpacity(0.28),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: FilledButton(
                        onPressed: auth.isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: _C.primary,
                          disabledBackgroundColor: _C.primary.withOpacity(0.7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: auth.isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Sign In',
                                style: GoogleFonts.poppins(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    const Divider(color: _C.border, height: 1),
                    const SizedBox(height: 24),

                    Center(
                      child: Text(
                        '© 2025 ACLC College of Mandaue. All rights reserved.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: _C.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'Official internal tool. Unauthorized access is strictly prohibited.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: _C.hint,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {Widget? suffixIcon}) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: _C.hint),
      filled: true,
      fillColor: _C.fill,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      enabledBorder: border(_C.border),
      focusedBorder: border(_C.primary),
      errorBorder: border(Colors.red.shade300),
      focusedErrorBorder: border(Colors.red.shade400),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
        color: _C.muted,
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  const _Blob({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: _C.blob, shape: BoxShape.circle),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'images/aclc_logo.jpeg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.school, color: _C.primary, size: 30),
        ),
      ),
    );
  }
}