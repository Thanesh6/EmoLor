import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/presentation/providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  String? _message;
  bool _isSuccess = false;
  final bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      setState(() {
        _isSuccess = false;
        _message = '⚠️ Please enter your email!';
      });
      return;
    }

    setState(() => _message = null); // Clear previous message

    try {
      await ref
          .read(authProvider.notifier)
          .recoverPassword(_emailController.text.trim());

      if (mounted) {
        setState(() {
          _isSuccess = true;
          _message = 'Reset link sent! Check your email.';
        });

        // Optional: Pop after delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && CanPopHelper.canPop(context)) {
            context.pop();
          }
        });
      }
    } on AuthException catch (e) {
      setState(() {
        _isSuccess = false;
        _message = '⚠️ ${e.message}';
      });
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _message = '⚠️ An unexpected error occurred.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFBAE6FD), // Sky Blue
              Color(0xFFE9D5FF), // Light Purple
              Color(0xFFFECDD3), // Light Pink
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Back Button Top Left (Optional, but using standard nav in SingleChildScrollView can be tricky layout-wise, so we stick to the card)

                  const SizedBox(height: 20),

                  Text(
                    'RECOVER ACCOUNT',
                    style: GoogleFonts.fredoka(
                      fontSize: 40, // Increased from 32
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6D28D9),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Container
                  Container(
                    width: 650, // Increased from 550
                    constraints: const BoxConstraints(maxWidth: 700),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 50, vertical: 40),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Message Display
                        if (_message != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isSuccess
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFFE5E5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: _isSuccess
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFFFF6B6B)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                      _isSuccess
                                          ? Icons.check_circle_outline
                                          : Icons.error_outline,
                                      color: _isSuccess
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFFF6B6B),
                                      size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _message!,
                                      style: GoogleFonts.fredoka(
                                        color: _isSuccess
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFFFF6B6B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const Text(
                          "Enter your email and we'll send you a link to reset your password.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22, // Increased from 16
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 20),

                        _buildStyledField(
                          controller: _emailController,
                          hint: 'Email',
                          icon: Icons.email_outlined,
                        ),

                        const SizedBox(height: 30),

                        // Button
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _resetPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF8B5CF6), // Violet
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40),
                                side: const BorderSide(
                                    color: Colors.black, width: 2.5),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : Text(
                                    'Send Recovery Link',
                                    style: GoogleFonts.fredoka(
                                      fontSize: 30, // Increased from 26
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: () => context.pop(),
                          child: Text(
                            'Back to Login',
                            style: GoogleFonts.fredoka(
                              fontSize: 22, // Increased from 18
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStyledField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.fredoka(
          fontSize: 26, // Increased from 22
          fontWeight: FontWeight.normal,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.fredoka(
            fontSize: 22, // Increased from 20
            fontWeight: FontWeight.normal,
            color: Colors.black38,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 20, right: 15),
            child: Icon(icon, color: Colors.black26, size: 28),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}

// Helper to avoid context usage across async gaps
class CanPopHelper {
  static bool canPop(BuildContext context) {
    return Navigator.canPop(context);
  }
}
