import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert'; // for utf8
import '../features/auth/presentation/providers/auth_provider.dart';
import '../core/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _parentContactController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _pinController =
      TextEditingController(); // NEW: PIN Controller

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToPolicy = false;
  String? _errorMessage;
  String? _successMessage; // New Success Message State

  // Role Selection
  String _selectedRole = 'caregiver';
  final List<Map<String, String>> _roles = [
    {'label': 'Caregiver (Parent / Guardian)', 'value': 'caregiver'},
    {'label': 'Organization / Centre', 'value': 'organization'},
  ];

  // Extended Avatar List
  final List<String> _avatars = [
    '🐱',
    '🐶',
    '🐰',
    '🦊',
    '🐼',
    '🐨',
    '🐯',
    '🦁',
    '🐮',
    '🐷',
    '🐸',
    '🐵',
    '🦄',
    '🐲',
    '🧚',
    '🦸',
    '🧜',
    '🤖',
    '👽',
    '👻'
  ];
  late String _selectedAvatar;

  @override
  void initState() {
    super.initState();
    _selectedAvatar = _avatars[0];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _parentContactController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  bool get _isCaregiverRegistration => _selectedRole == 'caregiver';
  bool get _isOrganizationRegistration => _selectedRole == 'organization';

  Future<void> _register() async {
    // Reset messages
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    // --- Common Validation (both roles) ---
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() {
        _errorMessage = '⚠️ Please fill in all required fields!';
      });
      return;
    }

    // Email format validation
    final emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w]{2,}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      setState(() {
        _errorMessage = '⚠️ Please enter a valid email address!';
      });
      return;
    }

    // Block admin email from self-registration
    if (_emailController.text.trim().toLowerCase() == 'admint@gmail.com') {
      setState(() {
        _errorMessage =
            '⚠️ This email is reserved. Please use a different email.';
      });
      return;
    }

    // Password length validation
    if (_passwordController.text.length < 8) {
      setState(() {
        _errorMessage = '⚠️ Password must be 8+ characters!';
      });
      return;
    }

    // Password match validation
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = '⚠️ Passwords do not match!';
      });
      return;
    }

    // Privacy policy agreement
    if (!_agreedToPolicy) {
      setState(() {
        _errorMessage = '\u26a0\ufe0f Please accept the Privacy Policy!';
      });
      return;
    }

    // Caregiver Specific Validation
    if (_isCaregiverRegistration) {
      if (_ageController.text.trim().isEmpty ||
          _parentContactController.text.trim().isEmpty) {
        setState(() {
          _errorMessage = '⚠️ Please fill in all required fields!';
        });
        return;
      }
    }

    // PIN Validation for Caregiver and Organization
    if (_isCaregiverRegistration || _isOrganizationRegistration) {
      if (_pinController.text.length != 4) {
        setState(() {
          _errorMessage = '⚠️ Please set a 4-digit PIN!';
        });
        return;
      }
    }

    try {
      // Check if email already exists
      final emailTaken =
          await AuthService().emailExists(_emailController.text.trim());
      if (emailTaken) {
        setState(() {
          _errorMessage = '⚠️ Email already registered. Please login.';
        });
        return;
      }

      String? pinHash;
      if (_isCaregiverRegistration || _isOrganizationRegistration) {
        // Hash PIN with SHA-256
        final bytes = utf8.encode(_pinController.text);
        final digest = sha256.convert(bytes);
        pinHash = digest.toString();
      }

      // 1. Sign Up
      await ref.read(authProvider.notifier).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            name: _nameController.text.trim(),
            role: _isOrganizationRegistration ? 'caregiver' : _selectedRole,
            pinHash: pinHash,
            accountType: _selectedRole,
            phone: (_isCaregiverRegistration || _isOrganizationRegistration)
                ? _parentContactController.text.trim()
                : null,
          );

      // Save selected avatar to profile (use RPC to bypass RLS)
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client.rpc('update_profile_avatar', params: {
          'p_user_id': userId,
          'p_avatar_url': _selectedAvatar,
        });
      }

      // Success — email confirmation sent. Stay on page, show top banner only.
      if (mounted) {
        setState(() {
          _successMessage =
              'Verification email sent to ${_emailController.text.trim()}!\nCheck your inbox and click the link to activate your account.';
        });
        // Auto-dismiss banner after 5 seconds, then go to login
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() => _successMessage = null);
            context.go('/login');
          }
        });
      }
    } catch (e) {
      setState(() {
        debugPrint('Registration Error: $e');
        _errorMessage =
            '⚠️ Registration failed: ${e.toString().replaceAll('Exception:', '').trim()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Container(
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
                      const SizedBox(height: 10),

                      // Header
                      Text(
                        'ACCOUNT REGISTRATION',
                        style: GoogleFonts.fredoka(
                          fontSize: 46,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6D28D9),
                        ),
                      ),

                      const SizedBox(height: 5),

                      // Register Container
                      Container(
                        constraints: const BoxConstraints(maxWidth: 800),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 15),
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
                            // Role Selection
                            Container(
                              margin: const EdgeInsets.only(bottom: 15),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedRole,
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down,
                                      color: Colors.black54),
                                  style: GoogleFonts.fredoka(
                                      fontSize: 20, color: Colors.black87),
                                  items: _roles.map((role) {
                                    return DropdownMenuItem(
                                      value: role['value'],
                                      child: Text(role['label']!),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedRole = val);
                                    }
                                  },
                                ),
                              ),
                            ),

                            // Error Message (Moved below Role Selection for better visibility)
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFE5E5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFFFF6B6B)),
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

                            // --- CAREGIVER FORM ---
                            if (_isCaregiverRegistration) ...[
                              // Avatar Section
                              Text(
                                'Pick your character!',
                                style: GoogleFonts.fredoka(
                                    fontSize: 22,
                                    color:
                                        Colors.black54), // Compacted: 25 -> 22
                              ),
                              const SizedBox(height: 5), // Compacted: 10 -> 5
                              SizedBox(
                                height: 70, // Compacted: 80 -> 70
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _avatars.length,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  itemBuilder: (context, index) {
                                    final avatar = _avatars[index];
                                    final isSelected =
                                        avatar == _selectedAvatar;
                                    return GestureDetector(
                                      onTap: () => setState(
                                          () => _selectedAvatar = avatar),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        width: isSelected
                                            ? 60
                                            : 50, // Compacted: 70 -> 60
                                        height: isSelected ? 60 : 50,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 5),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFFFDE68A)
                                              : Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFFF59E0B)
                                                : Colors.grey.shade200,
                                            width: isSelected ? 3 : 1,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                      color: Colors.orange
                                                          .withValues(
                                                              alpha: 0.3),
                                                      blurRadius: 8,
                                                      offset:
                                                          const Offset(0, 4))
                                                ]
                                              : [],
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          avatar,
                                          style: TextStyle(
                                              fontSize: isSelected
                                                  ? 32
                                                  : 26), // Compacted
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 10), // Compacted: 20 -> 10

                              // Row 1: Name | Email
                              Row(
                                children: [
                                  Expanded(
                                      child: _buildStyledField(
                                          controller: _nameController,
                                          hint: 'Name',
                                          icon: Icons.person_outline)),
                                  const SizedBox(width: 15),
                                  Expanded(
                                      child: _buildStyledField(
                                          controller: _emailController,
                                          hint: 'Email',
                                          icon: Icons.email_outlined,
                                          inputType:
                                              TextInputType.emailAddress)),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Row 2: Parent Contact | Age
                              Row(
                                children: [
                                  Expanded(
                                      child: _buildStyledField(
                                          controller: _parentContactController,
                                          hint: "Parent's Contact No.",
                                          icon: Icons.phone_outlined,
                                          inputType: TextInputType.phone)),
                                  const SizedBox(width: 15),
                                  Expanded(
                                      child: _buildStyledField(
                                          controller: _ageController,
                                          hint: 'Age',
                                          icon: Icons.cake_outlined,
                                          inputType: TextInputType.number)),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Row 3: PIN | Password
                              Row(
                                children: [
                                  Expanded(
                                      child: _buildStyledField(
                                          controller: _pinController,
                                          hint: 'Create 4-digit PIN',
                                          icon: Icons.lock_clock,
                                          inputType: TextInputType.number,
                                          isPassword: true)),
                                  const SizedBox(width: 15),
                                  Expanded(
                                      child: _buildStyledField(
                                          controller: _passwordController,
                                          hint: 'Password (8+ chars)',
                                          icon: Icons.lock_outline,
                                          isPassword: true,
                                          isObscured: _obscurePassword,
                                          toggleObscure: () => setState(() =>
                                              _obscurePassword =
                                                  !_obscurePassword))),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Row 4: Confirm Password
                              Row(
                                children: [
                                  Expanded(
                                      child: _buildStyledField(
                                          controller:
                                              _confirmPasswordController,
                                          hint: 'Confirm Password',
                                          icon: Icons.lock_outline,
                                          isPassword: true,
                                          isObscured: _obscureConfirmPassword,
                                          toggleObscure: () => setState(() =>
                                              _obscureConfirmPassword =
                                                  !_obscureConfirmPassword))),
                                  const SizedBox(width: 15),
                                  const Expanded(child: SizedBox()),
                                ],
                              ),
                            ] else if (_isOrganizationRegistration) ...[
                              // Row 1: Name | Email
                              Row(
                                children: [
                                  Expanded(
                                      child: _buildStyledField(
                                          controller: _nameController,
                                          hint: 'Centre / Organization Name',
                                          icon: Icons.person_outline)),
                                  const SizedBox(width: 15),
                                  Expanded(
                                      child: _buildStyledField(
                                          controller: _emailController,
                                          hint: 'Email',
                                          icon: Icons.email_outlined,
                                          inputType:
                                              TextInputType.emailAddress)),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Row 2: Contact No. | PIN
                              Row(
                                children: [
                                  Expanded(
                                      child: _buildStyledField(
                                          controller: _parentContactController,
                                          hint: 'Contact No.',
                                          icon: Icons.phone_outlined,
                                          inputType: TextInputType.phone)),
                                  const SizedBox(width: 15),
                                  Expanded(
                                      child: _buildStyledField(
                                          controller: _pinController,
                                          hint: 'Create 4-digit PIN',
                                          icon: Icons.lock_clock,
                                          inputType: TextInputType.number,
                                          isPassword: true)),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Row 3: Password | Confirm Password
                              Row(
                                children: [
                                  Expanded(
                                      child: _buildStyledField(
                                          controller: _passwordController,
                                          hint: 'Password (8+ chars)',
                                          icon: Icons.lock_outline,
                                          isPassword: true,
                                          isObscured: _obscurePassword,
                                          toggleObscure: () => setState(() =>
                                              _obscurePassword =
                                                  !_obscurePassword))),
                                  const SizedBox(width: 15),
                                  Expanded(
                                      child: _buildStyledField(
                                          controller:
                                              _confirmPasswordController,
                                          hint: 'Confirm Password',
                                          icon: Icons.lock_outline,
                                          isPassword: true,
                                          isObscured: _obscureConfirmPassword,
                                          toggleObscure: () => setState(() =>
                                              _obscureConfirmPassword =
                                                  !_obscureConfirmPassword))),
                                ],
                              ),
                              const SizedBox(height: 10),
                            ],

                            // Privacy Policy Checkbox
                            Row(
                                children: [
                                  Checkbox(
                                    value: _agreedToPolicy,
                                    activeColor: const Color(0xFF6D28D9),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5)),
                                    onChanged: (val) {
                                      setState(() {
                                        _agreedToPolicy = val ?? false;
                                        _errorMessage = null;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _showPrivacyPolicy(context),
                                      child: RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.fredoka(
                                              fontSize: 18,
                                              color: Colors.black87),
                                          children: [
                                            const TextSpan(
                                                text: 'I agree to the '),
                                            TextSpan(
                                              text: 'Privacy Policy',
                                              style: GoogleFonts.fredoka(
                                                color: const Color(0xFF0EA5E9),
                                                fontWeight: FontWeight.bold,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                            const SizedBox(height: 15), // Compacted: 30 -> 15

                            // Register Button
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
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
                                        'Create Account',
                                        style: GoogleFonts.fredoka(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Login Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Already have an account? ",
                                  style: GoogleFonts.fredoka(
                                    fontSize: 20,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.black87,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => context.pop(),
                                  style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero),
                                  child: Text(
                                    'Login',
                                    style: GoogleFonts.fredoka(
                                      fontSize: 20,
                                      color: const Color(0xFFC026D3),
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.none,
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

          // Custom Suspended Success Banner
          if (_successMessage != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669), // Emerald Green
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.white, size: 30),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: GoogleFonts.fredoka(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
    TextInputType? inputType,
  }) {
    return Tooltip(
      message: hint,
      waitDuration: const Duration(milliseconds: 500),
      textStyle: GoogleFonts.fredoka(color: Colors.white, fontSize: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF4A148C)
            .withValues(alpha: 0.9), // Deep purple backdrop
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(24),
        ),
        child: TextField(
          controller: controller,
          obscureText: isPassword ? isObscured : false,
          keyboardType: inputType,
          style: GoogleFonts.fredoka(
            fontSize: 20,
            fontWeight: FontWeight.normal,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.fredoka(
              fontSize: 18,
              fontWeight: FontWeight.normal,
              color: Colors.black38,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 20, right: 15),
              child: Icon(icon, color: Colors.black26, size: 24),
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
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Privacy Policy',
            style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(
            'We care about your privacy.\n\n'
            '1. We only collect the data you provide to us.\n'
            '2. We use this to personalize your EmoLor experience.\n'
            '3. Your data is safe with us and never shared with third parties.\n\n'
            'By joining, you agree to be an official user of EmoLor.',
            style: GoogleFonts.fredoka(fontSize: 16),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _agreedToPolicy = true);
            },
            child: Text('I Agree',
                style: GoogleFonts.fredoka(
                    fontSize: 18, color: const Color(0xFF6D28D9))),
          ),
        ],
      ),
    );
  }
}

// Helper to avoid context usage across async gaps if widget is unmounted
class CanPopHelper {
  static bool canPop(BuildContext context) {
    return Navigator.canPop(context);
  }
}
