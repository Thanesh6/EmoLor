import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _isSuccess = false;
        _message = '⚠️ Please enter both fields!';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _isSuccess = false;
        _message = '⚠️ Passwords do not match!';
      });
      return;
    }

    if (password.length < 8) {
      setState(() {
        _isSuccess = false;
        _message = '⚠️ Password must be at least 8 characters.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      // UCD011 Step 10-11 — actually update password via Supabase Auth
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );

      // IMPORTANT: After a password reset, Supabase leaves the
      // password-recovery session active. If we navigate straight to
      // '/login', the GoRouter redirect sees a logged-in user on an
      // auth route and bounces them into the role-based dashboard
      // (which, for a first-time caregiver, lands on profile creation /
      // onboarding).
      //
      // We must explicitly sign the user out so they enter the login
      // screen with NO session and have to re-authenticate using the
      // new password.
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {
        // Sign-out failures are non-fatal — we still want to send the
        // user to the login screen.
      }

      if (mounted) {
        setState(() {
          _isSuccess = true;
          _message = 'Password updated successfully!';
          _isLoading = false;
        });

        // Show success using Banner similar to Register. Capture the
        // messenger so we can reliably clear the banner later even after
        // navigation (a MaterialBanner never auto-dismisses on its own).
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearMaterialBanners(); // avoid stacking on repeat resets
        messenger.showMaterialBanner(
          MaterialBanner(
            content: Text(
              'Password updated! Please log in with your new password.',
              style: GoogleFonts.fredoka(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white),
            ),
            leading: const Icon(Icons.check_circle, color: Colors.white),
            backgroundColor: const Color(0xFF059669),
            actions: const [SizedBox.shrink()],
            elevation: 2,
          ),
        );

        // Auto-dismiss after 3s, THEN navigate. We clear the banner first and
        // defer the route swap by a frame, otherwise the banner gets orphaned
        // by the navigation and stays stuck on the login page.
        Future.delayed(const Duration(seconds: 3), () async {
          messenger.clearMaterialBanners();
          await Future.delayed(const Duration(milliseconds: 80));
          // UCD011 Step 11 — redirect to Login Page. Session already cleared
          // above, so the GoRouter redirect lets the user stay on /login.
          if (mounted) context.go('/login');
        });
      }
    } on AuthException catch (e) {
      setState(() {
        _isSuccess = false;
        _message = '⚠️ ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _message = '⚠️ An unexpected error occurred.';
        _isLoading = false;
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
                  Text(
                    'RESET PASSWORD',
                    style: GoogleFonts.fredoka(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6D28D9),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    width: 600,
                    constraints: const BoxConstraints(maxWidth: 650),
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
                        if (_message != null &&
                            !_isSuccess) // Only show error here, success is banner
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE5E5),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFFF6B6B)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: Color(0xFFFF6B6B), size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _message!,
                                      style: GoogleFonts.fredoka(
                                        color: const Color(0xFFFF6B6B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const Text(
                          "Enter a new password for your account.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildStyledField(
                          controller: _passwordController,
                          hint: 'New Password',
                          icon: Icons.lock_outline,
                          isPassword: true,
                          isObscured: _obscurePassword,
                          toggleObscure: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        const SizedBox(height: 15),
                        _buildStyledField(
                          controller: _confirmPasswordController,
                          hint: 'Confirm Password',
                          icon: Icons.lock_outline,
                          isPassword: true,
                          isObscured: _obscureConfirmPassword,
                          toggleObscure: () => setState(() =>
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _updatePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
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
                                    'Update Password',
                                    style: GoogleFonts.fredoka(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.0,
                                    ),
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
    bool isPassword = false,
    bool isObscured = false,
    VoidCallback? toggleObscure,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? isObscured : false,
        style: GoogleFonts.fredoka(
          fontSize: 24,
          fontWeight: FontWeight.normal,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.fredoka(
            fontSize: 22,
            fontWeight: FontWeight.normal,
            color: Colors.black38,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 20, right: 15),
            child: Icon(icon, color: Colors.black26, size: 28),
          ),
          suffixIcon: isPassword
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: IconButton(
                    icon: Icon(
                      isObscured ? Icons.visibility_off : Icons.visibility,
                      color: Colors.black26,
                    ),
                    onPressed: toggleObscure,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}
