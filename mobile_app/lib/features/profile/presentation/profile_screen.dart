import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../core/widgets/parent_gate_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final profile = await ref.read(authProvider.notifier).getUserProfile();
      if (mounted) {
        setState(() {
          _profileData = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load profile. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  String _formatRole(String? role) {
    if (role == null) return 'User';
    switch (role) {
      case 'caregiver':
        return 'Caregiver';
      case 'therapist':
        return 'Therapist';
      case 'admin':
        return 'Administrator';
      default:
        return role[0].toUpperCase() + role.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.value;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not Logged In")));
    }

    // Use DB data if available, fallback to auth metadata
    final displayName = _profileData?['full_name'] ??
        user.userMetadata?['full_name'] ??
        user.userMetadata?['name'] ??
        'Adventurer';
    final displayAvatar = _profileData?['avatar_url'] as String? ?? '😊';
    // profiles table has no email column; always use auth email
    final displayEmail = user.email ?? 'No Email';
    final displayRole =
        _formatRole(_profileData?['role'] ?? user.userMetadata?['role']);

    return Scaffold(
      appBar: AppBar(
        title: Text('My Profile',
            style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE0F2FE),
              Color(0xFFF3E8FF),
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 64, color: Colors.redAccent),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.fredoka(
                                fontSize: 18, color: Colors.red),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _loadProfile,
                            icon: const Icon(Icons.refresh),
                            label: Text('Retry',
                                style: GoogleFonts.fredoka(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 100),

                        // Avatar
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: const Color(0xFFC4B5FD),
                            child: Text(displayAvatar,
                                style: const TextStyle(fontSize: 50)),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Name
                        Text(
                          displayName,
                          style: GoogleFonts.fredoka(
                              fontSize: 32, fontWeight: FontWeight.bold),
                        ),

                        // Role badge
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            displayRole,
                            style: GoogleFonts.fredoka(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF7C3AED),
                            ),
                          ),
                        ),

                        // Email
                        const SizedBox(height: 8),
                        Text(
                          displayEmail,
                          style: GoogleFonts.fredoka(
                              fontSize: 18, color: Colors.black54),
                        ),

                        const SizedBox(height: 40),

                        // Actions Container
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              _buildActionButton(
                                context,
                                label: 'Edit Profile',
                                icon: Icons.edit,
                                color: const Color(0xFF3B82F6),
                                onTap: () {
                                  _checkParentGate(context, () {
                                    context.push('/edit-profile');
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildActionButton(
                                context,
                                label: 'Link Client Account',
                                icon: Icons.link,
                                color: const Color(0xFF10B981),
                                onTap: () {
                                  context.push('/link-account');
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildActionButton(
                                context,
                                label: 'Deactivate Account',
                                icon: Icons.delete_forever,
                                color: const Color(0xFFEF4444),
                                onTap: () {
                                  _checkParentGate(context, () {
                                    _confirmDeactivation(context, ref);
                                  });
                                },
                              ),
                              const SizedBox(height: 32),
                              _buildActionButton(
                                context,
                                label: 'Logout',
                                icon: Icons.logout,
                                color: Colors.grey,
                                isOutlined: true,
                                onTap: () {
                                  _confirmLogout(context);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isOutlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 92,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutlined ? Colors.transparent : color,
          foregroundColor: isOutlined ? color : Colors.white,
          elevation: isOutlined ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: isOutlined
                ? BorderSide(color: color, width: 2)
                : BorderSide.none,
          ),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 41),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.fredoka(
                  fontSize: 31, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _checkParentGate(BuildContext context, VoidCallback onSuccess) {
    showDialog(
      context: context,
      builder: (_) => ParentGateDialog(onSuccess: onSuccess),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        contentPadding: const EdgeInsets.fromLTRB(32, 20, 32, 12),
        actionsPadding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
        titlePadding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
        title: Text('Log Out?',
            style:
                GoogleFonts.fredoka(fontSize: 30, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.fredoka(fontSize: 21),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel',
                style: GoogleFonts.fredoka(fontSize: 20, color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(authProvider.notifier).signOut();
            },
            child: Text('Log Out',
                style: GoogleFonts.fredoka(fontSize: 20, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeactivation(BuildContext context, WidgetRef ref) {
    final passwordController = TextEditingController();
    String? dialogError;
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 28),
              const SizedBox(width: 8),
              Text('Deactivate Account',
                  style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    'Warning: Deactivating your account will:\n'
                    '\u2022 Immediately log you out\n'
                    '\u2022 Hide your profile from other users\n'
                    '\u2022 Prevent future login until reactivated\n'
                    '\u2022 Linked child profiles will become inaccessible',
                    style: GoogleFonts.fredoka(
                        fontSize: 14, color: Colors.red.shade700),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Enter your password to confirm:',
                    style: GoogleFonts.fredoka(fontSize: 15)),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: GoogleFonts.fredoka(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: GoogleFonts.fredoka(color: Colors.grey),
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    dialogError!,
                    style: GoogleFonts.fredoka(fontSize: 14, color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isProcessing ? null : () => Navigator.pop(dialogContext),
              child: Text('Cancel',
                  style: GoogleFonts.fredoka(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: isProcessing
                  ? null
                  : () async {
                      final password = passwordController.text;
                      if (password.isEmpty) {
                        setDialogState(() {
                          dialogError = 'Please enter your password.';
                        });
                        return;
                      }
                      setDialogState(() {
                        isProcessing = true;
                        dialogError = null;
                      });
                      try {
                        await ref
                            .read(authProvider.notifier)
                            .deactivateAccount(password);
                        // Dialog auto-closes as the widget tree rebuilds on
                        // sign-out; router redirects to /login.
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (e) {
                        setDialogState(() {
                          isProcessing = false;
                          dialogError =
                              'Incorrect password. Deactivation failed.';
                        });
                      }
                    },
              child: isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text('Deactivate',
                      style: GoogleFonts.fredoka(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
