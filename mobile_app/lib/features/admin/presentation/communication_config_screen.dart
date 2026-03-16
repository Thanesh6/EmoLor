import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/communication_config.dart';
import '../services/communication_config_service.dart';

/// UCD036 – Communication Config Screen
///
/// Presents a form with the current global messaging / media settings
/// and lets the admin update them.  Validates inputs inline and shows
/// a "Settings Updated" confirmation on save.
class CommunicationConfigScreen extends StatefulWidget {
  const CommunicationConfigScreen({super.key});

  @override
  State<CommunicationConfigScreen> createState() =>
      _CommunicationConfigScreenState();
}

class _CommunicationConfigScreenState extends State<CommunicationConfigScreen> {
  final CommunicationConfigService _service = CommunicationConfigService();
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  // Editable fields – initialised from DB in _loadConfig()
  late TextEditingController _maxSizeCtrl;
  late TextEditingController _retentionCtrl;
  late TextEditingController _maxMsgLenCtrl;
  late TextEditingController _fileTypesCtrl;
  bool _mediaUploadEnabled = true;
  bool _profanityFilterEnabled = true;

  @override
  void initState() {
    super.initState();
    _maxSizeCtrl = TextEditingController();
    _retentionCtrl = TextEditingController();
    _maxMsgLenCtrl = TextEditingController();
    _fileTypesCtrl = TextEditingController();
    _loadConfig();
  }

  @override
  void dispose() {
    _maxSizeCtrl.dispose();
    _retentionCtrl.dispose();
    _maxMsgLenCtrl.dispose();
    _fileTypesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final config = await _service.getConfig();
      if (!mounted) return;
      _maxSizeCtrl.text = config.maxAttachmentSizeMb.toString();
      _retentionCtrl.text = config.chatHistoryRetentionDays.toString();
      _maxMsgLenCtrl.text = config.maxMessageLength.toString();
      _fileTypesCtrl.text = config.allowedFileTypes.join(', ');
      _mediaUploadEnabled = config.mediaUploadEnabled;
      _profanityFilterEnabled = config.profanityFilterEnabled;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Failed to load configuration';
        _loading = false;
      });
    }
  }

  // ── Validation helpers ────────────────────────────────────────────────

  String? _validatePositiveInt(String? value, {int? max}) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    final n = int.tryParse(value.trim());
    if (n == null || n <= 0) {
      return 'Please enter a valid positive integer';
    }
    if (max != null && n > max) {
      return 'Maximum allowed value is $max';
    }
    return null;
  }

  String? _validateFileTypes(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'At least one file type is required';
    }
    final types = value
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();
    if (types.isEmpty) {
      return 'At least one file type is required';
    }
    final invalidPattern = RegExp(r'[^a-z0-9]');
    for (final t in types) {
      if (invalidPattern.hasMatch(t)) {
        return '"$t" is not a valid extension';
      }
    }
    return null;
  }

  // ── Save ──────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final types = _fileTypesCtrl.text
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();

    final updated = CommunicationConfig(
      maxAttachmentSizeMb: int.parse(_maxSizeCtrl.text.trim()),
      allowedFileTypes: types,
      chatHistoryRetentionDays: int.parse(_retentionCtrl.text.trim()),
      maxMessageLength: int.parse(_maxMsgLenCtrl.text.trim()),
      mediaUploadEnabled: _mediaUploadEnabled,
      profanityFilterEnabled: _profanityFilterEnabled,
    );

    setState(() => _saving = true);
    try {
      await _service.saveConfig(updated);
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnackBar('Settings Updated ✅', Colors.green);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnackBar('Failed to save: $e', Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(_loadError!,
                style: GoogleFonts.poppins(color: Colors.red[400])),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadConfig,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.settings_outlined,
                    color: Color(0xFF1E40AF), size: 28),
                const SizedBox(width: 12),
                Text(
                  'Communication Config',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reload',
                  onPressed: _loadConfig,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Global constraints for messaging and media storage.',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 28),

            // ── Media Settings Card ─────────────────────────────────
            _buildSectionCard(
              title: 'Media & Attachments',
              icon: Icons.attach_file,
              children: [
                _NumericField(
                  controller: _maxSizeCtrl,
                  label: 'Max Attachment Size (MB)',
                  hint: 'e.g. 10',
                  helperText: 'Maximum file size users can upload (1–100 MB)',
                  validator: (v) => _validatePositiveInt(v, max: 100),
                ),
                const SizedBox(height: 18),
                _buildFileTypesField(),
                const SizedBox(height: 18),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Media Upload Enabled',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500, fontSize: 14)),
                  subtitle: Text(
                    'When disabled, users cannot upload files or images.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey[600]),
                  ),
                  value: _mediaUploadEnabled,
                  activeTrackColor: const Color(0xFF1E40AF),
                  onChanged: (v) => setState(() => _mediaUploadEnabled = v),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Messaging Settings Card ─────────────────────────────
            _buildSectionCard(
              title: 'Messaging',
              icon: Icons.chat_outlined,
              children: [
                _NumericField(
                  controller: _maxMsgLenCtrl,
                  label: 'Max Message Length (characters)',
                  hint: 'e.g. 2000',
                  helperText: 'Maximum characters per message (100–10 000)',
                  validator: (v) => _validatePositiveInt(v, max: 10000),
                ),
                const SizedBox(height: 18),
                _NumericField(
                  controller: _retentionCtrl,
                  label: 'Chat History Retention (days)',
                  hint: 'e.g. 365',
                  helperText:
                      'Days before chat history is auto-deleted (1–3650). Set high to keep indefinitely.',
                  validator: (v) => _validatePositiveInt(v, max: 3650),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Safety Settings Card ────────────────────────────────
            _buildSectionCard(
              title: 'Safety & Compliance',
              icon: Icons.security_outlined,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Profanity Filter',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500, fontSize: 14)),
                  subtitle: Text(
                    'Automatically flag messages containing prohibited keywords.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey[600]),
                  ),
                  value: _profanityFilterEnabled,
                  activeTrackColor: const Color(0xFF1E40AF),
                  onChanged: (v) => setState(() => _profanityFilterEnabled = v),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Save Button ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save, color: Colors.white),
                label: Text(
                  _saving ? 'Saving…' : 'Save Configuration',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E40AF),
                  disabledBackgroundColor:
                      const Color(0xFF1E40AF).withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Section card builder ──────────────────────────────────────────────

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF1E40AF), size: 22),
                const SizedBox(width: 10),
                Text(title,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  // ── File types field (comma-separated) ────────────────────────────────

  Widget _buildFileTypesField() {
    return TextFormField(
      controller: _fileTypesCtrl,
      decoration: InputDecoration(
        labelText: 'Allowed File Types',
        hintText: 'jpg, png, pdf, doc',
        helperText: 'Comma-separated extensions (e.g. jpg, png, pdf)',
        helperMaxLines: 2,
        labelStyle: GoogleFonts.poppins(fontSize: 14),
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
        helperStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 1.5),
        ),
      ),
      style: GoogleFonts.poppins(fontSize: 14),
      validator: _validateFileTypes,
    );
  }
}

// ── Reusable numeric text field ─────────────────────────────────────────

class _NumericField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? helperText;
  final String? Function(String?)? validator;

  const _NumericField({
    required this.controller,
    required this.label,
    required this.hint,
    this.helperText,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        helperMaxLines: 2,
        labelStyle: GoogleFonts.poppins(fontSize: 14),
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
        helperStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 1.5),
        ),
        errorStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.red),
      ),
      style: GoogleFonts.poppins(fontSize: 14),
      validator: validator,
    );
  }
}
