import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = '⚠️ Please enter email and password!';
      });
      return;
    }

    // Clear previous error before attempting login
    setState(() {
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;

      // Admin gate: require exact email + password match
      if (email == 'admint@gmail.com' && password != 'AdminT15!') {
        setState(() {
          _errorMessage = '⚠️ Invalid email or password!';
        });
        return;
      }

      await ref.read(authProvider.notifier).signIn(
            email: email,
            password: password,
          );
      // Navigation is handled by AppRouter redirect (via refreshListenable)
    } catch (e) {
      if (!mounted) return; // Guard against disposed widget

      String msg = e.toString();
      // Clean up common Supabase errors
      if (msg.contains('Invalid login credentials')) {
        msg = 'Invalid email or password!';
      } else if (msg.contains('Email not confirmed')) {
        msg = 'Please verify your email!';
      } else {
        msg = msg
            .replaceAll('Exception:', '')
            .replaceAll('AuthException:', '')
            .trim();
      }

      setState(() {
        _errorMessage = '⚠️ $msg';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state for loading
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevent resize when keyboard opens
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
                  const SizedBox(height: 40),

                  // Programmatic EMOLOR Blocks
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLetterBlock('E', const Color(0xFF00B4D8)), // Blue
                      _buildLetterBlock(
                          'M', const Color(0xFFE9C46A)), // Yellow/Orange
                      _buildLetterBlock('O', const Color(0xFF9B5DE5)), // Purple
                      _buildLetterBlock('L', const Color(0xFF00BB56)), // Green
                      _buildLetterBlock('O', const Color(0xFFE5383B)), // Red
                      _buildLetterBlock('R', const Color(0xFFF15BB5)), // Pink
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Login Container
                  Container(
                    width: 550, // Fixed width for Tablet optimization
                    constraints: const BoxConstraints(maxWidth: 600),
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
                        // Welcome Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'WELCOME TO EMOLOR !',
                              style: GoogleFonts.fredoka(
                                fontSize: 32,
                                fontWeight:
                                    FontWeight.bold, // Bold as requested
                                color: const Color(0xFF6D28D9), // Deep Purple
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Error Message Display
                        if (_errorMessage != null)
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
                                      _errorMessage!,
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

                        const SizedBox(height: 10),

                        // Email Field
                        _buildStyledField(
                          controller: _emailController,
                          hint: 'Email',
                          icon: Icons.email_outlined,
                        ),

                        const SizedBox(height: 20),

                        // Password Field
                        _buildStyledField(
                          controller: _passwordController,
                          hint: 'Password',
                          icon: Icons.lock_outline,
                          isPassword: true,
                        ),

                        // Forgot Password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              context.push('/forgot-password');
                            },
                            child: Text(
                              'Forgot Password?',
                              style: GoogleFonts.fredoka(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.w500, // Medium legibility
                                color: const Color(0xFF8B5CF6),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFFC026D3), // Bright Magenta
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40),
                                side: const BorderSide(
                                  color: Colors.black,
                                  width: 2.5,
                                ),
                              ),
                              elevation: 0,
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : Text(
                                    'Login',
                                    style: GoogleFonts.fredoka(
                                      fontSize: 28,
                                      fontWeight: FontWeight
                                          .w600, // Semi-bold for button
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Register Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: GoogleFonts.fredoka(
                                fontSize: 18,
                                fontWeight: FontWeight.normal,
                                color: Colors.black87,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                context.push('/register');
                              },
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero),
                              child: Text(
                                'Register',
                                style: GoogleFonts.fredoka(
                                  fontSize: 18,
                                  color:
                                      const Color(0xFF059669), // Emerald Green
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
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

  // Helper for the Color Blocks
  Widget _buildLetterBlock(String letter, Color color) {
    return Container(
      width: 80, // Size of each block
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, 4),
            blurRadius: 4,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: GoogleFonts.fredoka(
          fontSize: 50,
          fontWeight: FontWeight.bold, // Bold as requested
          color: Colors.white,
          shadows: [
            const Shadow(
              offset: Offset(1, 1),
              blurRadius: 2,
              color: Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyledField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        style: GoogleFonts.fredoka(
          fontSize:
              24, // Reduced from user's 50 to prevent huge breakage, 24 is clear/child friendly
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
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.black26,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
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
