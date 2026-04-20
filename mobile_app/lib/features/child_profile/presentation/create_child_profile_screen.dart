import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/child_profile.dart';
import '../services/child_profile_service.dart';

class CreateChildProfileScreen extends StatefulWidget {
  const CreateChildProfileScreen({super.key});

  @override
  State<CreateChildProfileScreen> createState() =>
      _CreateChildProfileScreenState();
}

class _CreateChildProfileScreenState extends State<CreateChildProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ChildProfileService();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String? _selectedAvatar;
  bool _isLoading = false;

  // Existing child names (lower-cased) so we can reject duplicates.
  Set<String> _existingNames = <String>{};

  late AnimationController _glowCtrl;

  final List<String> _avatarOptions = [
    '👧', '👦', '🧒', '👶',
    '🦄', '🐻', '🐼', '🐨',
    '🦊', '🐱', '🐶', '🐰',
  ];

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadExistingNames();
  }

  Future<void> _loadExistingNames() async {
    try {
      final List<ChildProfile> existing =
          await _profileService.getMyChildProfiles();
      if (!mounted) return;
      setState(() {
        _existingNames = existing
            .map((p) => p.name.trim().toLowerCase())
            .toSet();
      });
    } catch (_) {
      // Non-fatal — we'll fall back to server-side rejection if needed.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _createProfile() async {
    if (_selectedAvatar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an avatar first')),
      );
      return;
    }
    // The form validator already catches duplicates and shows them inline
    // (red border + "That name is already used"), so we just gate on it.
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final age = int.tryParse(_ageController.text.trim());
      DateTime? dob;
      if (age != null) {
        final now = DateTime.now();
        dob = DateTime(now.year - age, now.month, now.day);
      }

      await _profileService.createChildProfile(
        name: _nameController.text.trim(),
        dateOfBirth: dob,
        avatarUrl: _selectedAvatar,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create profile: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  TextStyle _ts({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w600,
    Color color = Colors.black87,
  }) =>
      GoogleFonts.baloo2(fontSize: fontSize, fontWeight: fontWeight, color: color);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4FF),
      body: Stack(
        children: [
          // ── Background gradient ──────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEDE9FE), Color(0xFFF8F4FF)],
              ),
            ),
          ),

          // ── Glowing EMOLOR title at top ──────────────────────────
          Positioned(
            top: 36,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _glowCtrl,
                builder: (_, __) {
                  final glow = 8.0 + _glowCtrl.value * 18.0;
                  return Text(
                    'EMOLOR',
                    style: GoogleFonts.fredoka(
                      fontSize: 64,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6B21A8),
                      shadows: [
                        Shadow(
                          color: const Color(0xFF9333EA).withValues(
                              alpha: 0.5 + _glowCtrl.value * 0.4),
                          blurRadius: glow,
                        ),
                        Shadow(
                          color: const Color(0xFFD8B4FE).withValues(
                              alpha: 0.4 + _glowCtrl.value * 0.3),
                          blurRadius: glow + 8,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Main form — shifted slightly above centre ────────────
          Positioned.fill(
            top: 100,
            bottom: 90,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6B21A8).withValues(alpha: 0.1),
                        blurRadius: 30,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        Text(
                          "Create Child's Profile",
                          style: _ts(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6B21A8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Personalise the learning experience',
                          style: _ts(fontSize: 16, fontWeight: FontWeight.w500,
                              color: Colors.grey[500]!),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 26),

                        // ── 1. Avatar first ──────────────────────
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Choose an Avatar',
                            style: _ts(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF6B21A8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            childAspectRatio: 1,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: _avatarOptions.length,
                          itemBuilder: (context, index) {
                            final avatar = _avatarOptions[index];
                            final isSelected = _selectedAvatar == avatar;
                            return GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : () => setState(() => _selectedAvatar = avatar),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF6B21A8)
                                          .withValues(alpha: 0.15)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF6B21A8)
                                        : Colors.grey[300]!,
                                    width: isSelected ? 3 : 1.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF6B21A8)
                                                .withValues(alpha: 0.25),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          )
                                        ]
                                      : [],
                                ),
                                child: Center(
                                  child: Text(avatar,
                                      style: TextStyle(
                                          fontSize: isSelected ? 32 : 26)),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // ── 2. Name ──────────────────────────────
                        TextFormField(
                          controller: _nameController,
                          style: _ts(fontSize: 19),
                          decoration: InputDecoration(
                            labelText: "Child's Name",
                            labelStyle:
                                _ts(fontSize: 16, color: Colors.grey[600]!),
                            hintText: 'e.g. Thanesh',
                            hintStyle:
                                _ts(fontSize: 16, color: Colors.grey[400]!),
                            prefixIcon: const Icon(Icons.person_rounded,
                                color: Color(0xFF6B21A8), size: 26),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: Color(0xFF6B21A8), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter a name';
                            }
                            if (v.trim().length < 2) {
                              return 'Name must be at least 2 characters';
                            }
                            if (_existingNames
                                .contains(v.trim().toLowerCase())) {
                              return 'That name is already used';
                            }
                            return null;
                          },
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 16),

                        // ── 3. Age ───────────────────────────────
                        TextFormField(
                          controller: _ageController,
                          style: _ts(fontSize: 19),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Age',
                            labelStyle:
                                _ts(fontSize: 16, color: Colors.grey[600]!),
                            hintText: 'e.g. 7',
                            hintStyle:
                                _ts(fontSize: 16, color: Colors.grey[400]!),
                            prefixIcon: const Icon(Icons.cake_rounded,
                                color: Color(0xFF6B21A8), size: 26),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: Color(0xFF6B21A8), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter an age';
                            }
                            final age = int.tryParse(v.trim());
                            if (age == null || age < 1 || age > 18) {
                              return 'Enter a valid age (1–18)';
                            }
                            return null;
                          },
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 28),

                        // ── Create button ────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _createProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6B21A8),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 5,
                              shadowColor: const Color(0xFF6B21A8)
                                  .withValues(alpha: 0.4),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation(
                                          Colors.white),
                                    ),
                                  )
                                : Text('Create Profile',
                                    style: _ts(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Back button — large, bottom left ────────────────────
          Positioned(
            bottom: 24,
            left: 24,
            child: GestureDetector(
              onTap: _isLoading ? null : () => context.pop(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                      color: const Color(0xFF6B21A8).withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.arrow_back_rounded,
                      color: Color(0xFF6B21A8), size: 28),
                  const SizedBox(width: 10),
                  Text('Back',
                      style: _ts(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6B21A8))),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
