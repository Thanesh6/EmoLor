import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/child_profile_service.dart';

/// Screen for creating a new child profile
class CreateChildProfileScreen extends StatefulWidget {
  const CreateChildProfileScreen({super.key});

  @override
  State<CreateChildProfileScreen> createState() =>
      _CreateChildProfileScreenState();
}

class _CreateChildProfileScreenState extends State<CreateChildProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ChildProfileService();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String? _selectedAvatar;
  bool _isLoading = false;

  // Predefined avatar options
  final List<String> _avatarOptions = [
    '👧', '👦', '🧒', '👶',
    '🦄', '🐻', '🐼', '🐨',
    '🦊', '🐱', '🐶', '🐰',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _createProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedAvatar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an avatar')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Calculate DOB from age for backend compatibility
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

  TextStyle _textStyle({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w600,
    Color color = Colors.black87,
  }) {
    return GoogleFonts.baloo2(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4FF),
      appBar: AppBar(
        title: Text('New Profile',
            style: _textStyle(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF6B21A8))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF6B21A8)),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF9333EA), Color(0xFF6B21A8)]),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6B21A8).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                        child: Text('👤', style: TextStyle(fontSize: 40))),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    "Create Child's Profile",
                    style: _textStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6B21A8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This helps personalize the learning experience',
                    style: _textStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500]!),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    style: _textStyle(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: "Child's Name",
                      labelStyle: _textStyle(fontSize: 16, color: Colors.grey[600]!),
                      hintText: 'e.g. Thanesh',
                      hintStyle: _textStyle(fontSize: 16, color: Colors.grey[400]!),
                      prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF6B21A8)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF6B21A8), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),

                  // Age Field
                  TextFormField(
                    controller: _ageController,
                    style: _textStyle(fontSize: 18),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Age',
                      labelStyle: _textStyle(fontSize: 16, color: Colors.grey[600]!),
                      hintText: 'e.g. 7',
                      hintStyle: _textStyle(fontSize: 16, color: Colors.grey[400]!),
                      prefixIcon: const Icon(Icons.cake_rounded, color: Color(0xFF6B21A8)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF6B21A8), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an age';
                      }
                      final age = int.tryParse(value.trim());
                      if (age == null || age < 1 || age > 18) {
                        return 'Enter a valid age (1–18)';
                      }
                      return null;
                    },
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 24),

                  // Avatar Selection
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose an Avatar',
                      style: _textStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6B21A8)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF6B21A8).withValues(alpha: 0.15)
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
                                      color: const Color(0xFF6B21A8).withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(avatar,
                                style: TextStyle(fontSize: isSelected ? 30 : 26)),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // Create Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B21A8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                        shadowColor: const Color(0xFF6B21A8).withValues(alpha: 0.4),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text('Create Profile',
                              style: _textStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Cancel Button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _isLoading ? null : () => context.pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Cancel',
                          style: _textStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[500]!)),
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
}
