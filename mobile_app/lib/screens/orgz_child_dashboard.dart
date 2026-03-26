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
  final _ageController = TextEditingController();
  String? _selectedAvatar;
  bool _isCreating = false;

  final List<String> _avatarOptions = [
    '👧', '👦', '🧒', '👶',
    '🦄', '🐻', '🐼', '🐨',
    '🦊', '🐱', '🐶', '🐰',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
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
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      // Calculate DOB from age for backend
      DateTime? dob;
      final age = int.tryParse(_ageController.text.trim());
      if (age != null && age > 0) {
        final now = DateTime.now();
        dob = DateTime(now.year - age, now.month, now.day);
      }

      final profile = await _profileService.createChildProfile(
        name: name,
        dateOfBirth: dob,
        avatarUrl: _selectedAvatar,
      );
      if (mounted) {
        _nameController.clear();
        _ageController.clear();
        _selectedAvatar = null;
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Row(
        children: [
          // Logout button — 20% bigger
          GestureDetector(
            onTap: () => _confirmLogout(),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: const Color(0xFFFF6B6B), width: 2.5),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: Color(0xFFFF6B6B), size: 28),
            ),
          ),
          const Spacer(),
          // Title — 45% bigger, purple
          Text(
            'EMOLOR',
            style: GoogleFonts.baloo2(
              fontSize: 46,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF6B21A8),
              shadows: const [
                Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 3,
                    color: Colors.black12),
              ],
            ),
          ),
          const Spacer(),
          // Placeholder for symmetry
          const SizedBox(width: 56),
        ],
      ),
    );
  }

  Widget _buildProfileList() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 34),
            Text(
              "Who's Playing Today?",
              style: GoogleFonts.baloo2(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF6B21A8),
                shadows: const [
                  Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black12),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a child to start playing',
              style: GoogleFonts.baloo2(
                fontSize: 25,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B21A8).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 50),
            // Circular profile avatars in a wrap
            Wrap(
              spacing: 40,
              runSpacing: 34,
              alignment: WrapAlignment.center,
              children: [
                ..._profiles.map((profile) => _buildCircularProfile(profile)),
                // Add profile button
                _buildAddProfileCircle(),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularProfile(ChildProfile profile) {
    final avatarText = profile.avatarUrl ?? profile.name[0].toUpperCase();
    final isEmoji = profile.avatarUrl != null && profile.avatarUrl!.length <= 2;

    return GestureDetector(
      onTap: () => _selectChild(profile),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFF6B21A8), width: 5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B21A8).withValues(alpha: 0.25),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: isEmoji
                  ? Text(avatarText, style: const TextStyle(fontSize: 70))
                  : Text(
                      profile.name[0].toUpperCase(),
                      style: GoogleFonts.baloo2(
                        fontSize: 59,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF6B21A8),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            profile.name,
            style: GoogleFonts.baloo2(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4C1D95),
            ),
          ),
          if (profile.age != null)
            Text(
              'Age ${profile.age}',
              style: GoogleFonts.baloo2(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddProfileCircle() {
    return GestureDetector(
      onTap: () => setState(() => _showCreateForm = true),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.6),
              border: Border.all(color: const Color(0xFF6B21A8).withValues(alpha: 0.5), width: 4),
            ),
            child: const Center(
              child: Icon(Icons.add_rounded, color: Color(0xFF6B21A8), size: 62),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Add Child',
            style: GoogleFonts.baloo2(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B21A8).withValues(alpha: 0.7),
            ),
          ),
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
          const SizedBox(height: 16),
          // Title — big purple font
          Text(
            'Create Profile',
            style: GoogleFonts.baloo2(
              fontSize: 53,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF6B21A8),
              shadows: const [
                Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black12),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create profile of children',
            style: GoogleFonts.baloo2(
              fontSize: 25,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B21A8).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 28),
          // Form card
          Container(
            constraints: const BoxConstraints(maxWidth: 640),
            padding: const EdgeInsets.all(36),
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
                // Name field
                Text("Child's Name",
                    style: GoogleFonts.baloo2(
                        fontSize: 24, fontWeight: FontWeight.w700, color: const Color(0xFF4C1D95))),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  style: GoogleFonts.baloo2(fontSize: 25),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g. Thanesh',
                    hintStyle: GoogleFonts.baloo2(fontSize: 22, color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF6B21A8), size: 30),
                    filled: true,
                    fillColor: const Color(0xFFF5F3FF),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Color(0xFF6B21A8), width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  ),
                ),
                const SizedBox(height: 24),

                // Age field
                Text('Age',
                    style: GoogleFonts.baloo2(
                        fontSize: 24, fontWeight: FontWeight.w700, color: const Color(0xFF4C1D95))),
                const SizedBox(height: 10),
                TextField(
                  controller: _ageController,
                  style: GoogleFonts.baloo2(fontSize: 25),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'e.g. 7',
                    hintStyle: GoogleFonts.baloo2(fontSize: 22, color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.cake_rounded, color: Color(0xFF6B21A8), size: 30),
                    filled: true,
                    fillColor: const Color(0xFFF5F3FF),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Color(0xFF6B21A8), width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  ),
                ),
                const SizedBox(height: 30),

                // Avatar selection
                Text('Choose an Avatar',
                    style: GoogleFonts.baloo2(
                        fontSize: 24, fontWeight: FontWeight.w700, color: const Color(0xFF4C1D95))),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    childAspectRatio: 1,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: _avatarOptions.length,
                  itemBuilder: (context, index) {
                    final avatar = _avatarOptions[index];
                    final isSelected = _selectedAvatar == avatar;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedAvatar = avatar),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6B21A8).withValues(alpha: 0.15)
                              : const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF6B21A8) : Colors.grey[300]!,
                            width: isSelected ? 3.5 : 2,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: const Color(0xFF6B21A8).withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))]
                              : [],
                        ),
                        child: Center(
                          child: Text(avatar, style: TextStyle(fontSize: isSelected ? 42 : 36)),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Create button
                SizedBox(
                  width: double.infinity,
                  height: 72,
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : _createChild,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B21A8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      elevation: 4,
                      shadowColor: const Color(0xFF6B21A8).withValues(alpha: 0.4),
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            width: 30, height: 30,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                          )
                        : Text('Create & Start Playing',
                            style: GoogleFonts.baloo2(fontSize: 28, fontWeight: FontWeight.w700)),
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
                style: GoogleFonts.baloo2(
                  fontSize: 22,
                  color: const Color(0xFF6B21A8),
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: const Color(0xFF6B21A8),
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
