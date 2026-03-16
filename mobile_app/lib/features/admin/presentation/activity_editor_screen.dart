import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../../shared/models/activity_model.dart';
import '../services/activity_instructions_service.dart';

/// UCD020 – Activity Editor screen.
///
/// Lists every activity from the database and lets the admin edit
/// the instructional content (guidance text + visual demonstration).
class ActivityEditorScreen extends StatefulWidget {
  const ActivityEditorScreen({super.key});

  @override
  State<ActivityEditorScreen> createState() => _ActivityEditorScreenState();
}

class _ActivityEditorScreenState extends State<ActivityEditorScreen> {
  final ActivityInstructionsService _service = ActivityInstructionsService();

  bool _isLoading = true;
  String? _errorMessage;
  List<ActivityModel> _activities = [];
  List<ActivityModel> _filteredActivities = [];

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadActivities();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _activities = await _service.getAllActivities();
      _applyFilter();
    } catch (e) {
      _errorMessage = 'Failed to load activities: $e';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filteredActivities = q.isEmpty
          ? List.of(_activities)
          : _activities
              .where((a) =>
                  a.title.toLowerCase().contains(q) ||
                  a.description.toLowerCase().contains(q))
              .toList();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadActivities,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildSearch(),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Activity Editor',
            style:
                GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'Select an activity to define or update its instructions',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return SizedBox(
      width: 320,
      child: TextField(
        controller: _searchCtrl,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search activities…',
          hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[500]),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!)),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return _buildError();
    if (_filteredActivities.isEmpty) return _buildEmpty();
    return _buildList();
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
            onPressed: _loadActivities,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Text(
        _activities.isEmpty
            ? 'No activities in the database yet.'
            : 'No activities match your search.',
        style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      itemCount: _filteredActivities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final activity = _filteredActivities[i];
        return _ActivityTile(
          activity: activity,
          onTap: () => _openInstructionEditor(activity),
        );
      },
    );
  }

  // ── Open instruction editor ───────────────────────────────────────────

  Future<void> _openInstructionEditor(ActivityModel activity) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _InstructionEditorDialog(
        activity: activity,
        service: _service,
      ),
    );
    if (saved == true) {
      _loadActivities(); // refresh the list
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ─── Activity list tile ─────────────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _ActivityTile extends StatelessWidget {
  final ActivityModel activity;
  final VoidCallback onTap;

  const _ActivityTile({required this.activity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Type icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _typeColor(activity.type).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_typeIcon(activity.type),
                    color: _typeColor(activity.type)),
              ),
              const SizedBox(width: 14),

              // Title + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(activity.title,
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _chip(activity.type.value.toUpperCase(),
                            _typeColor(activity.type)),
                        const SizedBox(width: 8),
                        _chip(activity.difficulty.value, Colors.grey),
                        if (!activity.isActive) ...[
                          const SizedBox(width: 8),
                          _chip('INACTIVE', Colors.orange),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Edit arrow
              const Icon(Icons.edit_note_rounded,
                  color: Color(0xFF1E40AF), size: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w500, color: color)),
    );
  }

  IconData _typeIcon(ActivityType t) {
    switch (t) {
      case ActivityType.game:
        return Icons.sports_esports;
      case ActivityType.exercise:
        return Icons.fitness_center;
      case ActivityType.story:
        return Icons.menu_book;
      case ActivityType.art:
        return Icons.palette;
    }
  }

  Color _typeColor(ActivityType t) {
    switch (t) {
      case ActivityType.game:
        return Colors.indigo;
      case ActivityType.exercise:
        return Colors.teal;
      case ActivityType.story:
        return Colors.deepPurple;
      case ActivityType.art:
        return Colors.pink;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ─── Instruction editor dialog ──────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _InstructionEditorDialog extends StatefulWidget {
  final ActivityModel activity;
  final ActivityInstructionsService service;

  const _InstructionEditorDialog({
    required this.activity,
    required this.service,
  });

  @override
  State<_InstructionEditorDialog> createState() =>
      _InstructionEditorDialogState();
}

class _InstructionEditorDialogState extends State<_InstructionEditorDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _textCtrl;
  late TabController _tabController;

  bool _isLoadingData = true;
  bool _isSaving = false;
  String? _existingImageUrl;
  Uint8List? _newImageBytes;
  String? _newImageName;
  String? _imageError;

  // UCD021 — Completion feedback state
  late final TextEditingController _feedbackTextCtrl;
  String? _feedbackAnimation;
  String? _feedbackSound;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController();
    _feedbackTextCtrl = TextEditingController();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _loadExisting();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _feedbackTextCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Load existing instruction data from the raw activity row.
  Future<void> _loadExisting() async {
    try {
      final raw = await widget.service.getActivityRaw(widget.activity.id);
      _textCtrl.text = (raw['instruction_text'] as String?) ?? '';
      _existingImageUrl = raw['instruction_image_url'] as String?;
      // UCD021 — load feedback config
      _feedbackTextCtrl.text = (raw['feedback_text'] as String?) ?? '';
      _feedbackAnimation = raw['feedback_animation'] as String?;
      _feedbackSound = raw['feedback_sound'] as String?;
    } catch (e) {
      debugPrint('Failed to load existing instructions: $e');
    }
    if (mounted) setState(() => _isLoadingData = false);
  }

  // ── Image picking ─────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    if (file.bytes == null) return;
    final ext = file.name.split('.').last.toLowerCase();
    if (!{'jpg', 'jpeg', 'png'}.contains(ext)) {
      setState(() => _imageError = 'Only PNG and JPG images are allowed.');
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      setState(() => _imageError = 'Image must be under 5 MB.');
      return;
    }

    setState(() {
      _newImageBytes = file.bytes;
      _newImageName = file.name;
      _imageError = null;
    });
  }

  void _removeImage() {
    setState(() {
      _newImageBytes = null;
      _newImageName = null;
      _existingImageUrl = null;
    });
  }

  // ── Save ──────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      // 1. Upload new image if selected.
      String? imageUrl = _existingImageUrl;
      if (_newImageBytes != null && _newImageName != null) {
        imageUrl = await widget.service.uploadDemoImage(
          activityId: widget.activity.id,
          fileName: _newImageName!,
          fileBytes: _newImageBytes!,
        );
      }

      // If admin removed the image, pass null so the column is cleared.
      if (_existingImageUrl == null && _newImageBytes == null) {
        imageUrl = null;
      }

      // 2. Save instruction text + image URL.
      await widget.service.saveInstructions(
        activityId: widget.activity.id,
        instructionText: _textCtrl.text,
        instructionImageUrl: imageUrl,
      );

      // 3. UCD021 — Save feedback config.
      await widget.service.saveFeedbackConfig(
        activityId: widget.activity.id,
        feedbackText: _feedbackTextCtrl.text.trim().isEmpty
            ? null
            : _feedbackTextCtrl.text.trim(),
        feedbackAnimation: _feedbackAnimation,
        feedbackSound: _feedbackSound,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Configuration Saved.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.green[700],
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 640),
        child: _isLoadingData
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildTitleBar(),
                  _buildTabs(),
                  Expanded(child: _buildTabBody()),
                  _buildActions(),
                ],
              ),
      ),
    );
  }

  Widget _buildTitleBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Activity Editor',
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Text(widget.activity.title,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: Colors.grey[600])),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TabBar(
        controller: _tabController,
        labelStyle:
            GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14),
        labelColor: const Color(0xFF1E40AF),
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: const Color(0xFF1E40AF),
        tabs: const [
          Tab(text: 'Guidance Text'),
          Tab(text: 'Visual Demo'),
          Tab(text: 'Completion Feedback'),
        ],
      ),
    );
  }

  Widget _buildTabBody() {
    return Form(
      key: _formKey,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildTextTab(),
          _buildImageTab(),
          _buildFeedbackTab(),
        ],
      ),
    );
  }

  // ── Tab 1: Guidance text ──────────────────────────────────────────────

  Widget _buildTextTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter instructional guidance that will be shown to children '
            'before they start this activity.',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _textCtrl,
            style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'e.g. "Tap the colour that matches the face"',
              hintStyle:
                  GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!)),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Instruction text cannot be empty.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Text(
            '${_textCtrl.text.trim().length} characters',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Visual demonstration ───────────────────────────────────────

  Widget _buildImageTab() {
    final hasImage = _newImageBytes != null || (_existingImageUrl != null);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload a visual demonstration image that shows the child '
            'how to perform the activity (PNG or JPG, max 5 MB).',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          // Preview or picker
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                height: 260,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _newImageBytes != null
                    ? Image.memory(_newImageBytes!, fit: BoxFit.contain)
                    : Image.network(_existingImageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Center(
                              child: Icon(Icons.broken_image,
                                  size: 48, color: Colors.grey[400]),
                            )),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: Text('Replace Image',
                      style: GoogleFonts.poppins(fontSize: 13)),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _removeImage,
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: Colors.red[400]),
                  label: Text('Remove',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.red[400])),
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red[300]!)),
                ),
              ],
            ),
          ] else ...[
            InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color:
                          _imageError != null ? Colors.red : Colors.grey[300]!,
                      width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: 48, color: Colors.grey[500]),
                    const SizedBox(height: 10),
                    Text('Click to upload a demo image',
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: Colors.grey[600])),
                    Text('PNG or JPG, max 5 MB',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey[400])),
                  ],
                ),
              ),
            ),
          ],
          if (_imageError != null) ...[
            const SizedBox(height: 6),
            Text(_imageError!,
                style:
                    GoogleFonts.poppins(fontSize: 12, color: Colors.red[700])),
          ],
          if (_newImageName != null) ...[
            const SizedBox(height: 8),
            Text('Selected: $_newImageName',
                style:
                    GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
          ],
        ],
      ),
    );
  }

  // ── Tab 3: Completion Feedback (UCD021) ───────────────────────────────

  Widget _buildFeedbackTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configure the positive reinforcement shown when a child '
            'completes this activity.',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),

          // ── Feedback text ──
          Text('Feedback Message',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700])),
          const SizedBox(height: 6),
          TextFormField(
            controller: _feedbackTextCtrl,
            style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g. "Amazing! You got it right!"',
              hintStyle:
                  GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!)),
            ),
          ),
          const SizedBox(height: 20),

          // ── Animation style ──
          Text('Visual Animation',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700])),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _animationChip(null, 'None', Icons.block),
              _animationChip('confetti', 'Confetti', Icons.celebration),
              _animationChip('star_burst', 'Star Burst', Icons.auto_awesome),
              _animationChip('balloons', 'Balloons', Icons.bubble_chart),
            ],
          ),
          const SizedBox(height: 20),

          // ── Sound effect ──
          Text('Sound Effect',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700])),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _soundChip(null, 'None', Icons.volume_off),
              _soundChip('applause', 'Applause', Icons.emoji_people),
              _soundChip('chime', 'Chime', Icons.notifications_active),
              _soundChip('fanfare', 'Fanfare', Icons.music_note),
            ],
          ),
          const SizedBox(height: 16),

          // Validation hint
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.amber[800]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'At least one feedback element (message or visual '
                    'animation) must be defined.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.amber[900]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _animationChip(String? value, String label, IconData icon) {
    final selected = _feedbackAnimation == value;
    return ChoiceChip(
      avatar: Icon(icon,
          size: 18, color: selected ? Colors.white : Colors.grey[700]),
      label: Text(label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: selected ? Colors.white : Colors.grey[800],
          )),
      selected: selected,
      selectedColor: const Color(0xFF1E40AF),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
            color: selected ? const Color(0xFF1E40AF) : Colors.grey[300]!),
      ),
      onSelected: (_) => setState(() => _feedbackAnimation = value),
    );
  }

  Widget _soundChip(String? value, String label, IconData icon) {
    final selected = _feedbackSound == value;
    return ChoiceChip(
      avatar: Icon(icon,
          size: 18, color: selected ? Colors.white : Colors.grey[700]),
      label: Text(label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: selected ? Colors.white : Colors.grey[800],
          )),
      selected: selected,
      selectedColor: const Color(0xFF1E40AF),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
            color: selected ? const Color(0xFF1E40AF) : Colors.grey[300]!),
      ),
      onSelected: (_) => setState(() => _feedbackSound = value),
    );
  }

  // ── Actions bar ───────────────────────────────────────────────────────

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: Colors.grey[600])),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(_isSaving ? 'Saving…' : 'Save',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E40AF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
