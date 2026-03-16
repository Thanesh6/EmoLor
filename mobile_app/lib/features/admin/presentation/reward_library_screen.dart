import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../models/reward_catalog_item.dart';
import '../services/reward_library_service.dart';

/// UCD027 – Reward Library screen.
///
/// Allows the System Administrator to define, edit, and delete the global
/// library of digital rewards (badges, themes, stickers).
class RewardLibraryScreen extends StatefulWidget {
  const RewardLibraryScreen({super.key});

  @override
  State<RewardLibraryScreen> createState() => _RewardLibraryScreenState();
}

class _RewardLibraryScreenState extends State<RewardLibraryScreen> {
  final RewardLibraryService _service = RewardLibraryService();

  bool _isLoading = true;
  String? _errorMessage;
  List<RewardCatalogItem> _rewards = [];
  List<RewardCatalogItem> _filteredRewards = [];

  RewardCategory? _selectedCategory;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRewards();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data ─────────────────────────────────────────────────────────────

  Future<void> _loadRewards() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _rewards = await _service.getRewards();
      _applyFilter();
    } catch (e) {
      _errorMessage = 'Failed to load rewards: $e';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _applyFilter() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filteredRewards = _rewards.where((r) {
        final matchesCategory =
            _selectedCategory == null || r.category == _selectedCategory;
        final matchesSearch = query.isEmpty ||
            r.name.toLowerCase().contains(query) ||
            (r.description ?? '').toLowerCase().contains(query);
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadRewards,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildToolbar(),
            const SizedBox(height: 16),
            // Stats row
            _buildStatsRow(),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reward Library',
                style: GoogleFonts.poppins(
                    fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Define global rewards — badges, themes & stickers',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _showAddDialog,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text('Add New Reward',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E40AF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────────

  Widget _buildToolbar() {
    return Row(
      children: [
        // Category filter chips
        ...[null, ...RewardCategory.values].map((cat) {
          final isSelected = _selectedCategory == cat;
          final label = cat?.label ?? 'All';
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.grey[800],
                  )),
              selected: isSelected,
              selectedColor: const Color(0xFF1E40AF),
              backgroundColor: Colors.white,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF1E40AF)
                        : Colors.grey[300]!),
              ),
              onSelected: (_) {
                _selectedCategory = cat;
                _applyFilter();
              },
            ),
          );
        }),

        const Spacer(),

        // Search
        SizedBox(
          width: 260,
          child: TextField(
            controller: _searchCtrl,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search rewards…',
              hintStyle:
                  GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
              prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[500]),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final total = _rewards.length;
    final badges =
        _rewards.where((r) => r.category == RewardCategory.badge).length;
    final themes =
        _rewards.where((r) => r.category == RewardCategory.theme).length;
    final stickers =
        _rewards.where((r) => r.category == RewardCategory.sticker).length;
    final archived = _rewards.where((r) => !r.isActive).length;

    return Row(
      children: [
        _statChip('Total', '$total', const Color(0xFF1E40AF)),
        const SizedBox(width: 12),
        _statChip('🏅 Badges', '$badges', Colors.amber[700]!),
        const SizedBox(width: 12),
        _statChip('🎨 Themes', '$themes', Colors.purple[700]!),
        const SizedBox(width: 12),
        _statChip('⭐ Stickers', '$stickers', Colors.teal[700]!),
        if (archived > 0) ...[
          const SizedBox(width: 12),
          _statChip('📦 Archived', '$archived', Colors.grey[600]!),
        ],
      ],
    );
  }

  Widget _statChip(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w500, color: color)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(count,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _buildError();
    }
    if (_filteredRewards.isEmpty) {
      return _buildEmpty();
    }
    return _buildRewardGrid();
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
          const SizedBox(height: 12),
          Text(_errorMessage!,
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.red[700]),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loadRewards,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            _rewards.isEmpty
                ? 'No rewards yet — add your first!'
                : 'No rewards match your filters.',
            style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // ── Reward Grid ───────────────────────────────────────────────────────

  Widget _buildRewardGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
                ? 3
                : 2;
        return GridView.builder(
          itemCount: _filteredRewards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, index) {
            final reward = _filteredRewards[index];
            return _RewardCard(
              reward: reward,
              onEdit: () => _showEditDialog(reward),
              onDelete: () => _confirmDelete(reward),
              onArchive: () => _confirmArchive(reward),
            );
          },
        );
      },
    );
  }

  // ── Add dialog ────────────────────────────────────────────────────────

  Future<void> _showAddDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddRewardDialog(service: _service),
    );
    if (result == true) _loadRewards();
  }

  // ── Edit dialog ───────────────────────────────────────────────────────

  Future<void> _showEditDialog(RewardCatalogItem reward) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EditRewardDialog(reward: reward, service: _service),
    );
    if (result == true) _loadRewards();
  }

  // ── Archive ───────────────────────────────────────────────────────────

  Future<void> _confirmArchive(RewardCatalogItem reward) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Archive Reward?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'This will hide "${reward.name}" from the active catalog. '
          'It can be restored later.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.orange[700]),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Archive',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _service.archiveReward(reward.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reward archived.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.orange[700],
        ),
      );
      _loadRewards();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to archive: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Delete (with integrity check) ─────────────────────────────────────

  Future<void> _confirmDelete(RewardCatalogItem reward) async {
    // 1. Check if any child owns it
    final safe = await _service.canDelete(reward.id);
    if (!mounted) return;

    if (!safe) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange[700], size: 28),
              const SizedBox(width: 10),
              Text('Cannot Delete',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Cannot delete. This reward is currently owned by users. '
            'Please "Archive" it instead.',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('OK', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.orange[700]),
              onPressed: () {
                Navigator.pop(ctx);
                _confirmArchive(reward);
              },
              child: Text('Archive Instead',
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Reward?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'This will permanently delete "${reward.name}" and its icon '
          'from storage. This cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _service.deleteReward(reward.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reward deleted.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.green[700],
        ),
      );
      _loadRewards();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ─── Reward card widget ─────────────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _RewardCard extends StatelessWidget {
  final RewardCatalogItem reward;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onArchive;

  const _RewardCard({
    required this.reward,
    required this.onEdit,
    required this.onDelete,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: reward.isActive ? 1.0 : 0.55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon / thumbnail area
            Expanded(
              flex: 5,
              child: Container(
                color: _categoryBgColor(reward.category),
                child: Stack(
                  children: [
                    Center(
                      child: reward.hasIcon
                          ? Image.network(
                              reward.iconUrl!,
                              fit: BoxFit.contain,
                              width: 80,
                              height: 80,
                              errorBuilder: (_, __, ___) => _iconFallback(),
                            )
                          : _iconFallback(),
                    ),
                    // Archived banner
                    if (!reward.isActive)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey[700],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Archived',
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    // Category chip
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _categoryChip(reward.category),
                    ),
                  ],
                ),
              ),
            ),

            // Info area
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reward.name,
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.stars_rounded,
                            size: 16, color: Colors.amber[700]),
                        const SizedBox(width: 4),
                        Text('${reward.pointCost} pts',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber[800])),
                        if (reward.description != null &&
                            reward.description!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(reward.description!,
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: Colors.grey[500]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          reward.hasIcon
                              ? reward.iconFileName ?? 'icon'
                              : 'No icon',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        _actionButton(Icons.edit_outlined, Colors.blue, onEdit),
                        const SizedBox(width: 4),
                        if (reward.isActive)
                          _actionButton(
                              Icons.archive_outlined, Colors.orange, onArchive),
                        const SizedBox(width: 4),
                        _actionButton(
                            Icons.delete_outline, Colors.red, onDelete),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconFallback() {
    return Icon(
      reward.category == RewardCategory.badge
          ? Icons.emoji_events_rounded
          : reward.category == RewardCategory.theme
              ? Icons.palette_rounded
              : Icons.star_rounded,
      size: 48,
      color: Colors.grey[400],
    );
  }

  Color _categoryBgColor(RewardCategory cat) {
    switch (cat) {
      case RewardCategory.badge:
        return Colors.amber[50]!;
      case RewardCategory.theme:
        return Colors.purple[50]!;
      case RewardCategory.sticker:
        return Colors.teal[50]!;
    }
  }

  Widget _categoryChip(RewardCategory cat) {
    Color bg;
    Color fg;
    switch (cat) {
      case RewardCategory.badge:
        bg = Colors.amber[100]!;
        fg = Colors.amber[900]!;
        break;
      case RewardCategory.theme:
        bg = Colors.purple[100]!;
        fg = Colors.purple[900]!;
        break;
      case RewardCategory.sticker:
        bg = Colors.teal[100]!;
        fg = Colors.teal[900]!;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(cat.label,
          style: GoogleFonts.poppins(
              fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
    );
  }

  Widget _actionButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ─── Add Reward dialog ──────────────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _AddRewardDialog extends StatefulWidget {
  final RewardLibraryService service;
  const _AddRewardDialog({required this.service});

  @override
  State<_AddRewardDialog> createState() => _AddRewardDialogState();
}

class _AddRewardDialogState extends State<_AddRewardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController(text: '100');

  RewardCategory _category = RewardCategory.badge;
  PlatformFile? _pickedFile;
  Uint8List? _pickedBytes;
  String? _fileError;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _pointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: RewardLibraryService.allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    final error = RewardLibraryService.validateIconFile(
      fileName: file.name,
      sizeBytes: file.size,
    );
    setState(() {
      _pickedFile = file;
      _pickedBytes = file.bytes;
      _fileError = error;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fileError != null) return;

    setState(() => _isSaving = true);
    try {
      await widget.service.createReward(
        name: _nameCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        category: _category,
        pointCost: int.tryParse(_pointsCtrl.text.trim()) ?? 100,
        iconFileName: _pickedFile?.name,
        iconFileBytes: _pickedBytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Reward Created Successfully', style: GoogleFonts.poppins()),
          backgroundColor: Colors.green[700],
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Add New Reward',
          style:
              GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20)),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Category ──
                Text('Category',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 8),
                Row(
                  children: RewardCategory.values.map((cat) {
                    final isSelected = _category == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label:
                            Text('${cat.iconLabel.icon} ${cat.iconLabel.text}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[800],
                                )),
                        selected: isSelected,
                        selectedColor: const Color(0xFF1E40AF),
                        backgroundColor: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onSelected: (_) => setState(() => _category = cat),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // ── Name ──
                Text('Name',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: _inputDecoration(hint: 'e.g. Super Star'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 16),

                // ── Point Cost ──
                Text('Point Cost',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _pointsCtrl,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: _inputDecoration(hint: 'e.g. 100'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Point cost is required';
                    }
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 0) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Description ──
                Text('Description (optional)',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descCtrl,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: _inputDecoration(hint: 'Brief description…'),
                  maxLines: 2,
                ),
                const SizedBox(height: 18),

                // ── Icon upload ──
                Text('Visual Asset (PNG/SVG)',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickIcon,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _fileError != null
                              ? Colors.red
                              : Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _pickedFile != null
                              ? Icons.check_circle
                              : Icons.image_outlined,
                          size: 36,
                          color: _pickedFile != null
                              ? Colors.green
                              : Colors.grey[500],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _pickedFile != null
                              ? _pickedFile!.name
                              : 'Click to upload icon (PNG, JPG, SVG)',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: _pickedFile != null
                                ? Colors.black87
                                : Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_pickedFile != null) ...[
                          const SizedBox(height: 4),
                          Text(_formatBytes(_pickedFile!.size),
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.grey[500])),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_fileError != null) ...[
                  const SizedBox(height: 4),
                  Text(_fileError!,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.red[700])),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: Text('Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[600])),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_rounded, size: 18),
          label: Text(_isSaving ? 'Saving…' : 'Save',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E40AF),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!)),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ─── Edit Reward dialog ─────────────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _EditRewardDialog extends StatefulWidget {
  final RewardCatalogItem reward;
  final RewardLibraryService service;
  const _EditRewardDialog({required this.reward, required this.service});

  @override
  State<_EditRewardDialog> createState() => _EditRewardDialogState();
}

class _EditRewardDialogState extends State<_EditRewardDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _pointsCtrl;
  late RewardCategory _category;

  PlatformFile? _pickedFile;
  Uint8List? _pickedBytes;
  String? _fileError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.reward.name);
    _descCtrl = TextEditingController(text: widget.reward.description ?? '');
    _pointsCtrl =
        TextEditingController(text: widget.reward.pointCost.toString());
    _category = widget.reward.category;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _pointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: RewardLibraryService.allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    final error = RewardLibraryService.validateIconFile(
      fileName: file.name,
      sizeBytes: file.size,
    );
    setState(() {
      _pickedFile = file;
      _pickedBytes = file.bytes;
      _fileError = error;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fileError != null) return;

    setState(() => _isSaving = true);
    try {
      await widget.service.updateReward(
        rewardId: widget.reward.id,
        name: _nameCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        category: _category,
        pointCost: int.tryParse(_pointsCtrl.text.trim()) ?? 100,
        newIconFileName: _pickedFile?.name,
        newIconFileBytes: _pickedBytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reward updated.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.green[700],
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Edit Reward',
          style:
              GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20)),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Current icon preview
                if (widget.reward.hasIcon)
                  Container(
                    height: 80,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            widget.reward.iconUrl!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image, size: 40),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('Current icon',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: Colors.grey[600])),
                      ],
                    ),
                  ),

                // ── Category ──
                Text('Category',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 8),
                Row(
                  children: RewardCategory.values.map((cat) {
                    final isSelected = _category == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label:
                            Text('${cat.iconLabel.icon} ${cat.iconLabel.text}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[800],
                                )),
                        selected: isSelected,
                        selectedColor: const Color(0xFF1E40AF),
                        backgroundColor: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onSelected: (_) => setState(() => _category = cat),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // ── Name ──
                Text('Name',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: _inputDecoration(hint: 'Reward name'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 16),

                // ── Point Cost ──
                Text('Point Cost',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _pointsCtrl,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: _inputDecoration(hint: 'e.g. 100'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Point cost is required';
                    }
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 0) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Description ──
                Text('Description (optional)',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descCtrl,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: _inputDecoration(hint: 'Brief description…'),
                  maxLines: 2,
                ),
                const SizedBox(height: 18),

                // ── Replace icon ──
                Text('Replace Icon (optional)',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickIcon,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _fileError != null
                              ? Colors.red
                              : Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _pickedFile != null
                              ? Icons.check_circle
                              : Icons.upload_file_rounded,
                          size: 24,
                          color: _pickedFile != null
                              ? Colors.green
                              : Colors.grey[500],
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _pickedFile != null
                              ? _pickedFile!.name
                              : 'Click to upload new icon',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: _pickedFile != null
                                ? Colors.black87
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_fileError != null) ...[
                  const SizedBox(height: 4),
                  Text(_fileError!,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.red[700])),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: Text('Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[600])),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined, size: 18),
          label: Text(_isSaving ? 'Saving…' : 'Save Changes',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E40AF),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!)),
    );
  }
}
