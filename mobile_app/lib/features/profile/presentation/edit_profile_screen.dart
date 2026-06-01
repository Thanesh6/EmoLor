import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../../features/auth/presentation/providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  /// Pre-loaded profile map from ProfileScreen (avoids a second DB round-trip
  /// and prevents the avatar defaulting to 🐱 when the fetch is slow/fails).
  final Map<String, dynamic>? initialProfile;

  const EditProfileScreen({super.key, this.initialProfile});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingProfile = true;
  String? _userRole;

  // Avatars — same list as registration (non-final so saved avatar can be
  // prepended if it isn't already in the list).
  List<String> _avatars = [
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
    '👻',
  ];
  String _selectedAvatar = '🐱';

  @override
  void initState() {
    super.initState();
    // If the caller already has the profile data (passed via GoRouter extra),
    // populate immediately — no DB round-trip needed.
    if (widget.initialProfile != null) {
      _applyProfile(widget.initialProfile!);
      _isLoadingProfile = false;
    } else {
      _loadProfileData();
    }
  }

  /// Populate form fields from a profile map.
  void _applyProfile(Map<String, dynamic> profile) {
    _nameController.text = profile['full_name'] as String? ?? '';
    _phoneController.text = profile['phone_number'] as String? ?? '';
    _userRole = profile['role'] as String?;
    final av = profile['avatar_url'] as String?;
    if (av != null && av.isNotEmpty) {
      _selectedAvatar = av;
      // If the saved avatar is not already in the picker list, add it so it
      // appears highlighted and is not silently replaced on save.
      if (!_avatars.contains(av)) {
        _avatars.insert(0, av);
      }
    }
  }

  Future<void> _loadProfileData() async {
    try {
      final profile = await ref.read(authProvider.notifier).getUserProfile();
      if (mounted && profile != null) {
        setState(() {
          _applyProfile(profile);
          _isLoadingProfile = false;
        });
      } else {
        // Fallback to auth metadata for name only; avatar stays at default.
        final user = ref.read(authProvider).value;
        if (mounted) {
          setState(() {
            _nameController.text =
                user?.userMetadata?['full_name'] as String? ??
                    user?.userMetadata?['name'] as String? ??
                    '';
            _isLoadingProfile = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Validates phone: optional, but if provided must be digits/+/- and 7-15 chars
  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final trimmed = value.trim();
    final phoneRegex = RegExp(r'^[\+]?[0-9\-\s]{7,15}$');
    if (!phoneRegex.hasMatch(trimmed)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();

      await ref.read(authProvider.notifier).updateProfile(
            name: name,
            phone: phone.isNotEmpty ? phone : null,
            avatar: _selectedAvatar,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully',
                style: GoogleFonts.fredoka()),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e',
                style: GoogleFonts.fredoka()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile',
            style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar picker
                    Center(
                      child: Column(
                        children: [
                          Text('Choose Avatar',
                              style: GoogleFonts.fredoka(
                                  fontSize: 18, color: Colors.grey)),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _avatars.length,
                              itemBuilder: (context, index) {
                                final avatar = _avatars[index];
                                final isSelected = avatar == _selectedAvatar;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedAvatar = avatar),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 5),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.yellow.shade100
                                          : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: isSelected
                                              ? Colors.orange
                                              : Colors.grey.shade300),
                                    ),
                                    child: Text(avatar,
                                        style: const TextStyle(fontSize: 32)),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Name field
                    Text('Name',
                        style: GoogleFonts.fredoka(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _nameController,
                      style: GoogleFonts.fredoka(fontSize: 18),
                      decoration: InputDecoration(
                        hintText: 'Enter your name',
                        hintStyle: GoogleFonts.fredoka(
                            fontSize: 16, color: Colors.grey),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name cannot be blank';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Phone field
                    Text('Phone Number',
                        style: GoogleFonts.fredoka(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phoneController,
                      style: GoogleFonts.fredoka(fontSize: 18),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'e.g. +60123456789',
                        hintStyle: GoogleFonts.fredoka(
                            fontSize: 16, color: Colors.grey),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: _validatePhone,
                    ),

                    const SizedBox(height: 24),

                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : Text('Save Changes',
                                style: GoogleFonts.fredoka(
                                    fontSize: 18, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
