import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../models/content_asset.dart';
import '../services/content_library_service.dart';

/// UCD019 – Content Management screen.
///
/// Allows the System Administrator to upload, edit, and delete global
/// content assets (reward badges, activity images, story templates).
class ContentManagementScreen extends StatefulWidget {
  const ContentManagementScreen({super.key});

  @override
  State<ContentManagementScreen> createState() =>
      _ContentManagementScreenState();
}

class _ContentManagementScreenState extends State<ContentManagementScreen> {
  final ContentLibraryService _service = ContentLibraryService();

  bool _isLoading = true;
  String? _errorMessage;
  List<ContentAsset> _assets = [];
  List<ContentAsset> _filteredAssets = [];

  AssetCategory? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAssets();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Data ─────────────────────────────────────────────────────────────

  Future<void> _loadAssets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _assets = await _service.getAssets();
      _applyFilter();
    } catch (e) {
      _errorMessage = 'Failed to load assets: $e';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredAssets = _assets.where((a) {
        final matchesCategory =
            _selectedCategory == null || a.category == _selectedCategory;
        final matchesSearch = query.isEmpty ||
            a.title.toLowerCase().contains(query) ||
            (a.tag ?? '').toLowerCase().contains(query) ||
            a.fileName.toLowerCase().contains(query);
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadAssets,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildToolbar(),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Content Library',
                style: GoogleFonts.poppins(
                    fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Manage global assets — reward icons, images & story templates',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _showUploadDialog,
          icon: const Icon(Icons.cloud_upload_outlined, size: 20),
          label: Text('Upload New Asset',
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

  Widget _buildToolbar() {
    return Row(
      children: [
        // Category filter chips
        ...[null, ...AssetCategory.values].map((cat) {
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

        // Search field
        SizedBox(
          width: 260,
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by title or tag…',
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

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _buildError();
    }
    if (_filteredAssets.isEmpty) {
      return _buildEmpty();
    }
    return _buildAssetGrid();
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
            onPressed: _loadAssets,
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
          Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            _assets.isEmpty
                ? 'No assets yet — upload your first!'
                : 'No assets match your filters.',
            style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // ── Asset grid ────────────────────────────────────────────────────────

  Widget _buildAssetGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
                ? 3
                : 2;
        return GridView.builder(
          itemCount: _filteredAssets.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, index) => _AssetCard(
            asset: _filteredAssets[index],
            onEdit: () => _showEditDialog(_filteredAssets[index]),
            onDelete: () => _confirmDelete(_filteredAssets[index]),
          ),
        );
      },
    );
  }

  // ── Upload dialog ─────────────────────────────────────────────────────

  Future<void> _showUploadDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UploadAssetDialog(service: _service),
    );
    if (result == true) {
      _loadAssets();
    }
  }

  // ── Edit dialog ───────────────────────────────────────────────────────

  Future<void> _showEditDialog(ContentAsset asset) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EditAssetDialog(asset: asset, service: _service),
    );
    if (result == true) {
      _loadAssets();
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(ContentAsset asset) async {
    // 1. Check if in use
    final safe = await _service.canDelete(asset.id);
    if (!mounted) return;

    if (!safe) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Asset in use. Cannot delete.',
              style: GoogleFonts.poppins()),
          backgroundColor: Colors.orange[700],
        ),
      );
      return;
    }

    // 2. Confirm with admin
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Asset?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'This will permanently delete "${asset.title}" '
          'and its file from storage. This cannot be undone.',
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
      await _service.deleteAsset(asset.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Asset deleted.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.green[700],
        ),
      );
      _loadAssets();
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
// ─── Asset card widget ──────────────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _AssetCard extends StatelessWidget {
  final ContentAsset asset;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AssetCard({
    required this.asset,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumbnail / icon area
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.grey[100],
              child: asset.isImage
                  ? Image.network(asset.fileUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _iconFallback())
                  : _iconFallback(),
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
                  Text(asset.title,
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _categoryChip(asset.category),
                      const SizedBox(width: 6),
                      if (asset.tag != null && asset.tag!.isNotEmpty)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(asset.tag!,
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: Colors.purple[700]),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(asset.fileSizeFormatted,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.grey[500])),
                      const Spacer(),
                      _actionButton(Icons.edit_outlined, Colors.blue, onEdit),
                      const SizedBox(width: 4),
                      _actionButton(Icons.delete_outline, Colors.red, onDelete),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconFallback() {
    return Center(
      child: Icon(
        asset.isAudio ? Icons.audiotrack_rounded : Icons.insert_drive_file,
        size: 40,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _categoryChip(AssetCategory cat) {
    Color bg;
    Color fg;
    switch (cat) {
      case AssetCategory.rewardIcon:
        bg = Colors.amber[50]!;
        fg = Colors.amber[800]!;
        break;
      case AssetCategory.activityImage:
        bg = Colors.blue[50]!;
        fg = Colors.blue[800]!;
        break;
      case AssetCategory.storyTemplate:
        bg = Colors.teal[50]!;
        fg = Colors.teal[800]!;
        break;
      case AssetCategory.other:
        bg = Colors.grey[100]!;
        fg = Colors.grey[700]!;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child:
          Text(cat.label, style: GoogleFonts.poppins(fontSize: 11, color: fg)),
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
// ─── Upload dialog ──────────────────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _UploadAssetDialog extends StatefulWidget {
  final ContentLibraryService service;
  const _UploadAssetDialog({required this.service});

  @override
  State<_UploadAssetDialog> createState() => _UploadAssetDialogState();
}

class _UploadAssetDialogState extends State<_UploadAssetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  AssetCategory _category = AssetCategory.rewardIcon;
  PlatformFile? _pickedFile;
  Uint8List? _pickedBytes;
  String? _fileError;
  bool _isUploading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp3'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    // Validate
    final error = ContentLibraryService.validateFile(
      fileName: file.name,
      sizeBytes: file.size,
    );
    setState(() {
      _pickedFile = file;
      _pickedBytes = file.bytes;
      _fileError = error;
      // Auto-fill title if empty
      if (_titleCtrl.text.isEmpty) {
        _titleCtrl.text =
            file.name.replaceAll(RegExp(r'\.[^.]+$'), '').replaceAll('_', ' ');
      }
    });
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedFile == null || _pickedBytes == null) {
      setState(() => _fileError = 'Please select a file.');
      return;
    }
    if (_fileError != null) return;

    setState(() => _isUploading = true);
    try {
      await widget.service.uploadAsset(
        title: _titleCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        category: _category,
        tag: _tagCtrl.text.trim().isEmpty ? null : _tagCtrl.text.trim(),
        fileName: _pickedFile!.name,
        fileBytes: _pickedBytes!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload Successful', style: GoogleFonts.poppins()),
          backgroundColor: Colors.green[700],
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Upload New Asset',
          style:
              GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20)),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Category selector ──
                Text('Asset Category',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 6),
                DropdownButtonFormField<AssetCategory>(
                  initialValue: _category,
                  decoration: _inputDecoration(),
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
                  items: AssetCategory.values
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.label,
                              style: GoogleFonts.poppins(fontSize: 14))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                ),
                const SizedBox(height: 16),

                // ── File picker ──
                Text('File',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickFile,
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
                              : Icons.cloud_upload_outlined,
                          size: 36,
                          color: _pickedFile != null
                              ? Colors.green
                              : Colors.grey[500],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _pickedFile != null
                              ? _pickedFile!.name
                              : 'Click to select a file (PNG, JPG, MP3)',
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
                          Text(
                            _formatBytes(_pickedFile!.size),
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.grey[500]),
                          ),
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
                const SizedBox(height: 16),

                // ── Title ──
                Text('Title',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleCtrl,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: _inputDecoration(hint: 'e.g. Dinosaur Badge'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Title is required'
                      : null,
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
                const SizedBox(height: 16),

                // ── Tag ──
                Text('Tag (optional)',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _tagCtrl,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: _inputDecoration(hint: 'e.g. Brave'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context, false),
          child: Text('Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[600])),
        ),
        ElevatedButton.icon(
          onPressed: _isUploading ? null : _upload,
          icon: _isUploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.cloud_upload, size: 18),
          label: Text(_isUploading ? 'Uploading…' : 'Upload',
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
// ─── Edit dialog ────────────────────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _EditAssetDialog extends StatefulWidget {
  final ContentAsset asset;
  final ContentLibraryService service;
  const _EditAssetDialog({required this.asset, required this.service});

  @override
  State<_EditAssetDialog> createState() => _EditAssetDialogState();
}

class _EditAssetDialogState extends State<_EditAssetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _tagCtrl;
  late AssetCategory _category;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.asset.title);
    _descCtrl = TextEditingController(text: widget.asset.description ?? '');
    _tagCtrl = TextEditingController(text: widget.asset.tag ?? '');
    _category = widget.asset.category;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await widget.service.updateAsset(
        assetId: widget.asset.id,
        title: _titleCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        tag: _tagCtrl.text.trim().isEmpty ? null : _tagCtrl.text.trim(),
        category: _category,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Asset updated.', style: GoogleFonts.poppins()),
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
      title: Text('Edit Asset',
          style:
              GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20)),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // File info (read-only)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.asset.isImage
                            ? Icons.image
                            : widget.asset.isAudio
                                ? Icons.audiotrack
                                : Icons.insert_drive_file,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.asset.fileName,
                                style: GoogleFonts.poppins(
                                    fontSize: 13, fontWeight: FontWeight.w500)),
                            Text(widget.asset.fileSizeFormatted,
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Category ──
                Text('Category',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 6),
                DropdownButtonFormField<AssetCategory>(
                  initialValue: _category,
                  decoration: _inputDecoration(),
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
                  items: AssetCategory.values
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.label,
                              style: GoogleFonts.poppins(fontSize: 14))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                ),
                const SizedBox(height: 16),

                // ── Title ──
                Text('Title',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleCtrl,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: _inputDecoration(hint: 'Asset title'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Title is required'
                      : null,
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
                const SizedBox(height: 16),

                // ── Tag ──
                Text('Tag (optional)',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _tagCtrl,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: _inputDecoration(hint: 'e.g. Brave'),
                ),
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
