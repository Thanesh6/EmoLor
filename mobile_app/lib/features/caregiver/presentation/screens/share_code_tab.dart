import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/services/client_linking_service.dart';
import '../../../child_profile/services/child_profile_service.dart';
import '../../../child_profile/models/child_profile.dart';

/// UCD040 – Caregiver Share Code Tab
///
/// Lets the caregiver generate a unique linking code for each child,
/// copy it, and share it with their therapist.
class ShareCodeTab extends StatefulWidget {
  const ShareCodeTab({super.key});

  @override
  State<ShareCodeTab> createState() => _ShareCodeTabState();
}

class _ShareCodeTabState extends State<ShareCodeTab> {
  final ClientLinkingService _linkingService = ClientLinkingService();
  final ChildProfileService _profileService = ChildProfileService();

  List<ChildProfile> _children = [];
  List<LinkingCode> _codes = [];
  bool _loadingChildren = true;
  bool _loadingCodes = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _loadChildren();
    _loadCodes();
  }

  Future<void> _loadChildren() async {
    setState(() => _loadingChildren = true);
    try {
      final list = await _profileService.getMyChildProfiles();
      if (!mounted) return;
      setState(() {
        _children = list;
        _loadingChildren = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load children';
        _loadingChildren = false;
      });
    }
  }

  Future<void> _loadCodes() async {
    setState(() => _loadingCodes = true);
    try {
      final list = await _linkingService.getMyCodes();
      if (!mounted) return;
      setState(() {
        _codes = list;
        _loadingCodes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCodes = false;
      });
    }
  }

  Future<void> _generateCode(ChildProfile child) async {
    try {
      await _linkingService.generateShareCode(child.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New code generated for ${child.name}!'),
          backgroundColor: Colors.green[700],
        ),
      );
      _loadCodes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate code: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  Future<void> _revokeCode(LinkingCode code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Revoke Code?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
            'This will invalidate code ${code.code}. The therapist will no longer be able to use it.',
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _linkingService.revokeCode(code.id);
      _loadCodes();
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code "$code" copied to clipboard!'),
        backgroundColor: Colors.indigo[600],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = _loadingChildren || _loadingCodes;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(_error!, style: GoogleFonts.poppins(color: Colors.red[600])),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_children.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.child_care, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No child profiles found.\nCreate a child profile first.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Text(
            'Share Codes',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Generate a code and share it with your child\'s therapist to link accounts.',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),

          // Per-child section
          ..._children.map((child) {
            final activeCodes = _codes
                .where(
                  (c) => c.childProfileId == child.userId && c.isActive,
                )
                .toList();

            return _ChildCodeCard(
              child: child,
              activeCodes: activeCodes,
              onGenerate: () => _generateCode(child),
              onCopy: _copyCode,
              onRevoke: _revokeCode,
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Child Code Card ─────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _ChildCodeCard extends StatelessWidget {
  final ChildProfile child;
  final List<LinkingCode> activeCodes;
  final VoidCallback onGenerate;
  final void Function(String code) onCopy;
  final void Function(LinkingCode code) onRevoke;

  const _ChildCodeCard({
    required this.child,
    required this.activeCodes,
    required this.onGenerate,
    required this.onCopy,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Child info + generate button
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.indigo[100],
                  backgroundImage: child.avatarUrl != null
                      ? NetworkImage(child.avatarUrl!)
                      : null,
                  child: child.avatarUrl == null
                      ? Text(
                          child.name.isNotEmpty
                              ? child.name[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo[700],
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.name,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      if (child.age != null)
                        Text(
                          'Age ${child.age}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onGenerate,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    'Generate Code',
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),

            // Active codes
            if (activeCodes.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Text(
                'Active Codes',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              ...activeCodes.map((code) => _CodeRow(
                    code: code,
                    onCopy: () => onCopy(code.code),
                    onRevoke: () => onRevoke(code),
                  )),
            ] else ...[
              const SizedBox(height: 10),
              Text(
                'No active code. Tap "Generate Code" to create one.',
                style:
                    GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  final LinkingCode code;
  final VoidCallback onCopy;
  final VoidCallback onRevoke;

  const _CodeRow({
    required this.code,
    required this.onCopy,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final expiresIn = code.expiresAt.difference(DateTime.now().toUtc());
    final expiresLabel = expiresIn.inHours > 0
        ? '${expiresIn.inHours}h left'
        : '${expiresIn.inMinutes}m left';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.indigo[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo[200]!),
      ),
      child: Row(
        children: [
          // Code display
          Text(
            code.code,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
              color: const Color(0xFF1E40AF),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            expiresLabel,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
          ),
          const Spacer(),
          // Copy button
          IconButton(
            icon: Icon(Icons.copy, size: 18, color: Colors.indigo[400]),
            tooltip: 'Copy code',
            onPressed: onCopy,
          ),
          // Revoke button
          IconButton(
            icon: Icon(Icons.close, size: 18, color: Colors.red[400]),
            tooltip: 'Revoke code',
            onPressed: onRevoke,
          ),
        ],
      ),
    );
  }
}
