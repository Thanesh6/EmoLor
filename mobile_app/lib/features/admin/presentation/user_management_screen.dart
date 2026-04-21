import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/admin_service.dart';

/// UCD009 – User Management screen.
/// Displays all registered users with search, status badge, and
/// Activate / Deactivate actions with confirmation dialog + audit log.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filterRole = 'all'; // all | caregiver | child

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────
  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final users = await _adminService.getAllUsers();
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load users: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((u) {
        // Role filter
        if (_filterRole != 'all' && u['role'] != _filterRole) return false;
        // Text search
        if (query.isNotEmpty) {
          final name = (u['full_name'] ?? '').toString().toLowerCase();
          final role = (u['role'] ?? '').toString().toLowerCase();
          return name.contains(query) || role.contains(query);
        }
        return true;
      }).toList();
    });
  }

  // ── Activate / Deactivate ───────────────────────────────────────────
  void _confirmToggleStatus(Map<String, dynamic> user) {
    final isActive = user['is_active'] == true;
    final userName = user['full_name'] ?? 'this user';
    final action = isActive ? 'deactivate' : 'activate';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isActive ? Icons.block : Icons.check_circle_outline,
              color: isActive ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(
              isActive ? 'Deactivate User' : 'Activate User',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Confirm $action for "$userName"?\n\n'
          '${isActive ? 'This will prevent the user from logging in.' : 'This will allow the user to log in again.'}',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? Colors.red : Colors.green,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _toggleStatus(user);
            },
            child: Text(
              isActive ? 'Deactivate' : 'Activate',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleStatus(Map<String, dynamic> user) async {
    final userId = user['user_id'] as String;
    final newActive = !(user['is_active'] == true);

    try {
      await _adminService.setUserActive(
        targetUserId: userId,
        active: newActive,
      );

      // Refresh list to show new status (UCD009 step 8)
      await _loadUsers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newActive
                  ? 'User "${user['full_name']}" successfully reactivated.'
                  : 'User "${user['full_name']}" deactivated successfully.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: newActive ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────
  String _formatRole(String? role) {
    switch (role) {
      case 'caregiver':
        return 'Caregiver';
      case 'child':
        return 'Child';
      case 'admin':
        return 'Admin';
      default:
        return role ?? 'Unknown';
    }
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'caregiver':
        return const Color(0xFF0EA5E9);
      case 'child':
        return const Color(0xFFFB923C);
      case 'admin':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  IconData _roleIcon(String? role) {
    switch (role) {
      case 'caregiver':
        return Icons.family_restroom;
      case 'child':
        return Icons.child_care;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  // ── Build ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header bar ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Management',
                style: GoogleFonts.poppins(
                    fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${_filteredUsers.length} user${_filteredUsers.length == 1 ? '' : 's'} found',
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Search + Role filter
              Row(
                children: [
                  // Search field
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search by name...',
                        hintStyle: GoogleFonts.poppins(color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Role selector
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filterRole,
                          isExpanded: true,
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: Colors.black87),
                          items: const [
                            DropdownMenuItem(
                                value: 'all', child: Text('All Roles')),
                            DropdownMenuItem(
                                value: 'caregiver', child: Text('Caregivers')),
                            DropdownMenuItem(
                                value: 'child', child: Text('Children')),
                            DropdownMenuItem(
                                value: 'admin', child: Text('Admins')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _filterRole = val);
                              _applyFilter();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Refresh button
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: _loadUsers,
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Body ───────────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          Text(_errorMessage!,
                              style: GoogleFonts.poppins(color: Colors.red)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadUsers,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _filteredUsers.isEmpty
                      ? Center(
                          child: Text(
                            'No users match your criteria.',
                            style: GoogleFonts.poppins(
                                color: Colors.grey.shade600),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredUsers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _buildUserCard(_filteredUsers[index]);
                          },
                        ),
        ),
      ],
    );
  }

  // ── Single user card ────────────────────────────────────────────────
  Widget _buildUserCard(Map<String, dynamic> user) {
    final isActive = user['is_active'] == true;
    final role = user['role'] as String?;
    final isAdmin = role == 'admin'; // Admins can't be deactivated

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: _roleColor(role).withValues(alpha: 0.15),
              child: Icon(_roleIcon(role), color: _roleColor(role), size: 24),
            ),
            const SizedBox(width: 14),

            // Name + role + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['full_name'] ?? 'Unnamed',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.black87 : Colors.grey,
                      decoration: isActive ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Role chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _roleColor(role).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _formatRole(role),
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _roleColor(role)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isActive ? Icons.check_circle : Icons.cancel,
                              size: 12,
                              color: isActive ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isActive ? 'Active' : 'Deactivated',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isActive ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Action button
            if (!isAdmin)
              ElevatedButton(
                onPressed: () => _confirmToggleStatus(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isActive ? Colors.red.shade50 : Colors.green.shade50,
                  foregroundColor: isActive ? Colors.red : Colors.green,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isActive
                          ? Colors.red.shade200
                          : Colors.green.shade200,
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: Text(
                  isActive ? 'Deactivate' : 'Activate',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              )
            else
              Chip(
                label: Text('System',
                    style:
                        GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                backgroundColor: Colors.grey.shade100,
              ),
          ],
        ),
      ),
    );
  }
}
