import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TherapistSettingsTab extends StatefulWidget {
  const TherapistSettingsTab({super.key});

  @override
  State<TherapistSettingsTab> createState() => _TherapistSettingsTabState();
}

class _TherapistSettingsTabState extends State<TherapistSettingsTab> {
  bool _emailNotifications = true;
  bool _sessionReminders = true;
  bool _progressAlerts = false;
  bool _biometric = false;
  String _displayName = 'Therapist';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final metaName = user.userMetadata?['full_name'] as String?;
      if (metaName != null && metaName.isNotEmpty) {
        if (mounted) setState(() { _displayName = metaName; _email = user.email ?? ''; });
        return;
      }
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('user_id', user.id)
          .maybeSingle();
      final name = profile?['full_name'] as String?;
      if (mounted) setState(() { _displayName = name ?? 'Therapist'; _email = user.email ?? ''; });
    } catch (_) {}
  }

  TextStyle _ts({double size = 16, FontWeight weight = FontWeight.w500, Color color = Colors.black87}) =>
      GoogleFonts.baloo2(fontSize: size, fontWeight: weight, color: color);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: _ts(size: 26, weight: FontWeight.w700, color: const Color(0xFF1E3A8A))),
          Text('Manage your account and preferences', style: _ts(size: 15, color: Colors.grey[600]!)),
          const SizedBox(height: 32),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column
              Expanded(
                child: Column(
                  children: [
                    _buildSection(
                      icon: Icons.person_rounded,
                      title: 'Profile',
                      color: const Color(0xFF1E40AF),
                      children: [
                        _buildInfoRow(Icons.badge_rounded, 'Display Name', _displayName),
                        _buildInfoRow(Icons.email_rounded, 'Email', _email.isNotEmpty ? _email : 'Not set'),
                        _buildInfoRow(Icons.phone_rounded, 'Phone', '+60 12-345 6789'),
                        _buildInfoRow(Icons.business_rounded, 'Clinic', 'EmoLor Therapy Centre'),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: Text('Edit Profile', style: _ts(size: 15, weight: FontWeight.w600, color: const Color(0xFF1E40AF))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF1E40AF)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      icon: Icons.lock_rounded,
                      title: 'Security',
                      color: const Color(0xFF6B21A8),
                      children: [
                        _buildToggleRow('Biometric Login', 'Use fingerprint or face ID', _biometric,
                            (v) => setState(() => _biometric = v), const Color(0xFF6B21A8)),
                        const Divider(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showChangePasswordDialog(context),
                            icon: const Icon(Icons.key_rounded, size: 18),
                            label: Text('Change Password', style: _ts(size: 15, weight: FontWeight.w600, color: const Color(0xFF6B21A8))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF6B21A8)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right column
              Expanded(
                child: Column(
                  children: [
                    _buildSection(
                      icon: Icons.notifications_rounded,
                      title: 'Notifications',
                      color: const Color(0xFF065F46),
                      children: [
                        _buildToggleRow('Email Notifications', 'Receive updates via email', _emailNotifications,
                            (v) => setState(() => _emailNotifications = v), const Color(0xFF065F46)),
                        const Divider(height: 24),
                        _buildToggleRow('Session Reminders', 'Alert before upcoming sessions', _sessionReminders,
                            (v) => setState(() => _sessionReminders = v), const Color(0xFF065F46)),
                        const Divider(height: 24),
                        _buildToggleRow('Progress Alerts', 'Notify on patient milestones', _progressAlerts,
                            (v) => setState(() => _progressAlerts = v), const Color(0xFF065F46)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      icon: Icons.info_outline_rounded,
                      title: 'About',
                      color: const Color(0xFF92400E),
                      children: [
                        _buildInfoRow(Icons.apps_rounded, 'App', 'EmoLor'),
                        _buildInfoRow(Icons.tag_rounded, 'Version', '1.0.0'),
                        _buildInfoRow(Icons.medical_services_rounded, 'Portal', 'Therapist'),
                        _buildInfoRow(Icons.gavel_rounded, 'License', 'Professional'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title, style: _ts(size: 17, weight: FontWeight.w700, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 10),
          Text('$label:', style: _ts(size: 14, color: Colors.grey[600]!)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: _ts(size: 14, weight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildToggleRow(String title, String subtitle, bool value, ValueChanged<bool> onChanged, Color color) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _ts(size: 15, weight: FontWeight.w600)),
              Text(subtitle, style: _ts(size: 13, color: Colors.grey[500]!)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: color,
        ),
      ],
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final newPw = TextEditingController();
    final confirmPw = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Change Password', style: _ts(size: 18, weight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newPw,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                labelStyle: _ts(size: 14, color: Colors.grey[600]!),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPw,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                labelStyle: _ts(size: 14, color: Colors.grey[600]!),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: _ts(size: 15, color: Colors.grey[600]!))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Save', style: _ts(size: 15, color: Colors.white, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
