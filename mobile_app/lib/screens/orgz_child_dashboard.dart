import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/child_profile/models/child_profile.dart';
import '../features/child_profile/services/child_profile_service.dart';

class OrgzChildDashboard extends ConsumerStatefulWidget {
  const OrgzChildDashboard({super.key});

  @override
  ConsumerState<OrgzChildDashboard> createState() =>
      _OrgzChildDashboardState();
}

class _OrgzChildDashboardState extends ConsumerState<OrgzChildDashboard> {
  final _profileService = ChildProfileService();
  List<ChildProfile> _profiles = [];
  bool _isLoading = true;
  bool _showCreateForm = false;

  // Form
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  DateTime? _selectedDob;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    try {
      final profiles = await _profileService.getMyChildProfiles();
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _isLoading = false;
          // Auto-show form if no profiles
          if (profiles.isEmpty) _showCreateForm = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createChild() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      final profile = await _profileService.createChildProfile(
        name: name,
        dateOfBirth: _selectedDob,
      );
      if (mounted) {
        _nameController.clear();
        _dobController.clear();
        _selectedDob = null;
        setState(() {
          _showCreateForm = false;
          _isCreating = false;
        });
        // Navigate to child dashboard
        context.go('/child/home', extra: {
          'showSwitch': true,
          'childName': profile.name,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create profile: ${e.toString()}'),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 5),
      firstDate: DateTime(2005),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDob = picked;
        _dobController.text =
            '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  void _selectChild(ChildProfile profile) {
    context.go('/child/home', extra: {
      'showSwitch': true,
      'childName': profile.name,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF7DD3FC),
              Color(0xFFFDE68A),
              Color(0xFF86EFAC),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: _showCreateForm
                          ? _buildCreateForm()
                          : _buildProfileList(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          // Logout button
          GestureDetector(
            onTap: () => _confirmLogout(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(color: const Color(0xFFFF6B6B), width: 2),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: Color(0xFFFF6B6B), size: 22),
            ),
          ),
          const Spacer(),
          // Title
          Text(
            'EmoLor',
            style: GoogleFonts.baloo2(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: const [
                Shadow(
                    offset: Offset(2, 2),
                    blurRadius: 4,
                    color: Colors.black26),
              ],
            ),
          ),
          const Spacer(),
          // Placeholder for symmetry
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildProfileList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            'Who\'s Playing Today?',
            style: GoogleFonts.baloo2(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              shadows: const [
                Shadow(
                    offset: Offset(2, 2),
                    blurRadius: 4,
                    color: Colors.black26),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a child or add a new one',
            style: GoogleFonts.baloo2(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 24),
          // Child profile cards
          ..._profiles.map((profile) => _buildProfileCard(profile)),
          const SizedBox(height: 16),
          // Add child button
          _buildAddChildButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileCard(ChildProfile profile) {
    return GestureDetector(
      onTap: () => _selectChild(profile),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
                ),
                border: Border.all(color: const Color(0xFF6D28D9), width: 3),
              ),
              child: Center(
                child: profile.avatarUrl != null
                    ? ClipOval(
                        child: Image.network(profile.avatarUrl!,
                            width: 52, height: 52, fit: BoxFit.cover),
                      )
                    : Text(
                        profile.name[0].toUpperCase(),
                        style: GoogleFonts.baloo2(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF6D28D9),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            // Name + age
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: GoogleFonts.fredoka(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E1B4B),
                    ),
                  ),
                  if (profile.age != null)
                    Text(
                      'Age ${profile.age}',
                      style: GoogleFonts.fredoka(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
            // Play arrow
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6D28D9).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Color(0xFF6D28D9), size: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddChildButton() {
    return GestureDetector(
      onTap: () => setState(() => _showCreateForm = true),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline_rounded,
                color: Color(0xFF6D28D9), size: 28),
            const SizedBox(width: 12),
            Text(
              'Add New Child',
              style: GoogleFonts.fredoka(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6D28D9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Avatar placeholder
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.8),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text('👶', style: TextStyle(fontSize: 50)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _profiles.isEmpty ? 'Create Your First Child' : 'Add a New Child',
            style: GoogleFonts.baloo2(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              shadows: const [
                Shadow(
                    offset: Offset(2, 2),
                    blurRadius: 4,
                    color: Colors.black26),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Form card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Child\'s Name',
                  style: GoogleFonts.fredoka(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4C1D95),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  style: GoogleFonts.fredoka(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Enter child\'s name',
                    hintStyle: GoogleFonts.fredoka(color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.person_outline_rounded,
                        color: Color(0xFF6D28D9)),
                    filled: true,
                    fillColor: const Color(0xFFF5F3FF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: Color(0xFF6D28D9), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Date of Birth (Optional)',
                  style: GoogleFonts.fredoka(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4C1D95),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _dobController,
                  readOnly: true,
                  onTap: _pickDob,
                  style: GoogleFonts.fredoka(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Tap to select date',
                    hintStyle: GoogleFonts.fredoka(color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.cake_outlined,
                        color: Color(0xFF6D28D9)),
                    filled: true,
                    fillColor: const Color(0xFFF5F3FF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: Color(0xFF6D28D9), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // Create button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : _createChild,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D28D9),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Create & Start Playing',
                            style: GoogleFonts.fredoka(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          // Back to profiles button (if profiles exist)
          if (_profiles.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _showCreateForm = false),
              child: Text(
                'Back to profiles',
                style: GoogleFonts.fredoka(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log Out?',
            style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.fredoka(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:
                Text('Cancel', style: GoogleFonts.fredoka(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(authProvider.notifier).signOut();
            },
            child: Text('Log Out',
                style: GoogleFonts.fredoka(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
