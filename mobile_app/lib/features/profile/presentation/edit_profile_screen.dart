import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../../features/auth/presentation/providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

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

  // Avatars — same list as registration
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
    '👻',
  ];
  String _selectedAvatar = '🐱';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final profile = await ref.read(authProvider.notifier).getUserProfile();
      if (mounted && profile != null) {
        setState(() {
          _nameController.text = profile['full_name'] ?? '';
          _phoneController.text = profile['phone_number'] ?? '';
          _userRole = profile['role'] as String?;
          final av = profile['avatar_url'] as String?;
          if (av != null && av.isNotEmpty) _selectedAvatar = av;
          _isLoadingProfile = false;
        });
      } else {
        // Fallback to auth metadata
        final user = ref.read(authProvider).value;
        if (mounted) {
          setState(() {
            _nameController.text = user?.userMetadata?['full_name'] ??
                user?.userMetadata?['name'] ??
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

  /// Shows a dialog to change the caregiver's 4-digit PIN
  void _showChangePinDialog() {
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    String? dialogError;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.lock_outline,
                  color: Color(0xFF6B21A8), size: 24),
              const SizedBox(width: 8),
              Text('Change PIN',
                  style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPinController,
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
                style: GoogleFonts.fredoka(fontSize: 20, letterSpacing: 8),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '• • • •',
                  labelText: 'New 4-digit PIN',
                  labelStyle: GoogleFonts.fredoka(fontSize: 14),
                  counterText: '',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPinController,
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
                style: GoogleFonts.fredoka(fontSize: 20, letterSpacing: 8),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '• • • •',
                  labelText: 'Confirm PIN',
                  labelStyle: GoogleFonts.fredoka(fontSize: 14),
                  counterText: '',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 12),
                Text(
                  dialogError!,
                  style: GoogleFonts.fredoka(fontSize: 14, color: Colors.red),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: Text('Cancel',
                  style: GoogleFonts.fredoka(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B21A8)),
              onPressed: isSaving
                  ? null
                  : () async {
                      final newPin = newPinController.text;
                      final confirmPin = confirmPinController.text;

                      if (newPin.length != 4 ||
                          !RegExp(r'^\d{4}$').hasMatch(newPin)) {
                        setDialogState(() {
                          dialogError = 'PIN must be exactly 4 digits.';
                        });
                        return;
                      }
                      if (newPin != confirmPin) {
                        setDialogState(() {
                          dialogError = 'PINs do not match.';
                        });
                        return;
                      }

                      setDialogState(() {
                        isSaving = true;
                        dialogError = null;
                      });

                      try {
                        final bytes = utf8.encode(newPin);
                        final digest = sha256.convert(bytes);
                        final pinHash = digest.toString();

                        await ref
                            .read(authProvider.notifier)
                            .updatePinHash(pinHash);

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('PIN updated successfully',
                                  style: GoogleFonts.fredoka()),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSaving = false;
                          dialogError = 'Failed to update PIN. Try again.';
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text('Save',
                      style: GoogleFonts.fredoka(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
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

                    // Change PIN section (caregivers only)
                    if (_userRole == 'caregiver') ...[
                      const Divider(height: 40),
                      Text('Change Parent PIN',
                          style: GoogleFonts.fredoka(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                        'Your PIN is used to access restricted areas from Child Mode.',
                        style: GoogleFonts.fredoka(
                            fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed:
                              _isLoading ? null : () => _showChangePinDialog(),
                          icon: const Icon(Icons.lock_outline),
                          label: Text('Change PIN',
                              style: GoogleFonts.fredoka(fontSize: 16)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6B21A8),
                            side: const BorderSide(color: Color(0xFF6B21A8)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                      ),
                    ],

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
