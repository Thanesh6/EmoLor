import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/services/client_linking_service.dart';
import '../../services/client_record_service.dart';
import 'client_record_screen.dart';

/// UCD039 – My Clients List
///
/// Shows all children linked to the therapist via `therapist_client_link`.
/// Tapping a child card navigates to the full [ClientRecordScreen].
class MyClientsScreen extends StatefulWidget {
  const MyClientsScreen({super.key});

  @override
  State<MyClientsScreen> createState() => _MyClientsScreenState();
}

class _MyClientsScreenState extends State<MyClientsScreen> {
  final ClientRecordService _service = ClientRecordService();
  final ClientLinkingService _linkingService = ClientLinkingService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<ClientSummary> _clients = [];
  List<ClientSummary> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.getMyClients();
      if (!mounted) return;
      setState(() {
        _clients = list;
        _filtered = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load clients';
        _loading = false;
      });
    }
  }

  void _applySearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = _clients;
      } else {
        _filtered = _clients.where((c) {
          return c.childName.toLowerCase().contains(q) ||
              c.caregiverName.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  void _openRecord(ClientSummary client) async {
    final linked = await _service.isLinkedToChild(client.childId);
    if (!mounted) return;

    if (!linked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Access Denied. You are no longer linked to this client.'),
          backgroundColor: Colors.red[700],
        ),
      );
      _loadClients(); // Refresh list
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ClientRecordScreen(
          childId: client.childId,
          childName: client.childName,
          caregiverId: client.caregiverId,
        ),
      ),
    );

    // Refresh if client was unlinked (UCD041)
    if (result == true && mounted) {
      _loadClients();
    }
  }

  // ── UCD040 – Link New Account dialog ──────────────────────────────────

  Future<void> _showLinkDialog() async {
    final codeCtrl = TextEditingController();
    LinkVerifyResult? preview;
    String? errorMsg;
    bool verifying = false;
    bool confirming = false;

    final linked = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlg) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.link, color: Colors.indigo[600]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enter Client Linking Code',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ask the caregiver for their unique sharing code to link their child to your caseload.',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),

                    // Code input
                    TextField(
                      controller: codeCtrl,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                      decoration: InputDecoration(
                        hintText: 'A7X-92B',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 28,
                          letterSpacing: 4,
                          color: Colors.grey[300],
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 16),
                      ),
                      enabled: preview == null && !verifying,
                    ),

                    // Error message
                    if (errorMsg != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red[600], size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMsg!,
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Confirmation preview
                    if (preview != null && preview!.isValid) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green[300]!),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.indigo[100],
                              backgroundImage: preview!.childAvatarUrl != null
                                  ? NetworkImage(preview!.childAvatarUrl!)
                                  : null,
                              child: preview!.childAvatarUrl == null
                                  ? Text(
                                      (preview!.childName ?? 'C')[0]
                                          .toUpperCase(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo[700],
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    preview!.childName ?? 'Child',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (preview!.childAge != null)
                                    Text(
                                      'Age ${preview!.childAge}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(Icons.check_circle,
                                color: Colors.green[600], size: 28),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel',
                      style: GoogleFonts.poppins(color: Colors.grey[600])),
                ),

                // Verify or Confirm button
                if (preview == null)
                  ElevatedButton(
                    onPressed: verifying
                        ? null
                        : () async {
                            if (codeCtrl.text.trim().isEmpty) {
                              setDlg(() =>
                                  errorMsg = 'Please enter a linking code.');
                              return;
                            }
                            setDlg(() {
                              verifying = true;
                              errorMsg = null;
                            });

                            final result =
                                await _linkingService.verifyCode(codeCtrl.text);

                            if (!ctx.mounted) return;
                            if (result.isValid) {
                              setDlg(() {
                                preview = result;
                                verifying = false;
                              });
                            } else {
                              setDlg(() {
                                errorMsg = result.errorMessage;
                                verifying = false;
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E40AF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: verifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Verify'),
                  )
                else
                  ElevatedButton(
                    onPressed: confirming
                        ? null
                        : () async {
                            setDlg(() => confirming = true);
                            try {
                              await _linkingService.confirmLink(preview!);
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              if (!ctx.mounted) return;
                              setDlg(() {
                                errorMsg = 'Failed to link: $e';
                                confirming = false;
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: confirming
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Confirm Link'),
                  ),
              ],
            );
          },
        );
      },
    );

    codeCtrl.dispose();

    if (linked == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Client Linked Successfully!'),
          backgroundColor: Colors.green[700],
        ),
      );
      _loadClients();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.people, color: Colors.indigo[600], size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'My Clients',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _showLinkDialog,
                    icon: const Icon(Icons.link, size: 18),
                    label: Text(
                      'Link New Account',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E40AF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: _loadClients,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchCtrl,
                onChanged: _applySearch,
                decoration: InputDecoration(
                  hintText: 'Search by child or caregiver name…',
                  hintStyle: GoogleFonts.poppins(fontSize: 14),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            _applySearch('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),

        // ── Body ────────────────────────────────────────────────
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
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
              onPressed: _loadClients,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              _clients.isEmpty
                  ? 'No clients linked yet.'
                  : 'No clients match your search.',
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadClients,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _ClientCard(
          client: _filtered[i],
          onTap: () => _openRecord(_filtered[i]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Client Card ─────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _ClientCard extends StatelessWidget {
  final ClientSummary client;
  final VoidCallback onTap;

  const _ClientCard({required this.client, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.indigo[100],
                backgroundImage: client.avatarUrl != null
                    ? NetworkImage(client.avatarUrl!)
                    : null,
                child: client.avatarUrl == null
                    ? Text(
                        client.childName.isNotEmpty
                            ? client.childName[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo[700],
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.childName,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (client.age != null)
                      Text(
                        'Age ${client.age}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 14, color: Colors.teal[400]),
                        const SizedBox(width: 4),
                        Text(
                          client.caregiverName,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.teal[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
