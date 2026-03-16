import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/engagement_analytics_service.dart';
import '../services/performance_stats_service.dart';
import '../services/report_generation_service.dart';

/// UCD047 – Export Reports
///
/// A lightweight bottom-sheet modal triggered by the "Export", "Download"
/// or "Share" icon on any analytics view. It compiles the **current data
/// view** (already loaded and filtered) into the user's chosen file
/// format (PDF / CSV) and saves it to the device. Shows a success
/// notification with a Share action on completion, or an error message
/// if generation fails.
class QuickExportModal extends StatefulWidget {
  final String childName;

  /// The date range that produced [engagementData] / [performanceData].
  final DateTime periodStart;
  final DateTime periodEnd;

  /// Pre-loaded data from the hosting screen. At least one must be non-null.
  final EngagementData? engagementData;
  final PerformanceData? performanceData;

  /// Optional human-readable label for the active filter summary so the
  /// user can verify what they are exporting.
  final String? filterSummary;

  const QuickExportModal({
    super.key,
    required this.childName,
    required this.periodStart,
    required this.periodEnd,
    this.engagementData,
    this.performanceData,
    this.filterSummary,
  });

  /// Convenience launcher. Returns the file path on success, null on cancel.
  static Future<String?> show(
    BuildContext context, {
    required String childName,
    required DateTime periodStart,
    required DateTime periodEnd,
    EngagementData? engagementData,
    PerformanceData? performanceData,
    String? filterSummary,
  }) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => QuickExportModal(
        childName: childName,
        periodStart: periodStart,
        periodEnd: periodEnd,
        engagementData: engagementData,
        performanceData: performanceData,
        filterSummary: filterSummary,
      ),
    );
  }

  @override
  State<QuickExportModal> createState() => _QuickExportModalState();
}

class _QuickExportModalState extends State<QuickExportModal> {
  final ReportGenerationService _service = ReportGenerationService();

  ReportFormat _format = ReportFormat.pdf;
  bool _exporting = false;
  String? _errorMessage;
  String? _successPath;

  // ── Export action ────────────────────────────────────────────────────

  Future<void> _export() async {
    setState(() {
      _exporting = true;
      _errorMessage = null;
      _successPath = null;
    });

    try {
      // Build payload directly from the already-loaded data —
      // no additional network call is needed.
      final payload = ReportPayload(
        childName: widget.childName,
        start: widget.periodStart,
        end: widget.periodEnd,
        engagement: widget.engagementData,
        performance: widget.performanceData,
        hasData: (widget.engagementData != null &&
                !widget.engagementData!.isEmpty) ||
            (widget.performanceData != null &&
                !widget.performanceData!.isEmpty),
      );

      if (!payload.hasData) {
        if (!mounted) return;
        setState(() {
          _exporting = false;
          _errorMessage =
              'No data available to export. Try a different period or filter.';
        });
        return;
      }

      String filePath;
      if (_format == ReportFormat.pdf) {
        filePath = await _service.generatePdf(payload);
      } else {
        filePath = await _service.generateCsv(payload);
      }

      if (!mounted) return;
      setState(() {
        _exporting = false;
        _successPath = filePath;
      });
    } catch (e) {
      if (!mounted) return;
      // Alternative Flow – Generation Failed
      setState(() {
        _exporting = false;
        _errorMessage = 'Export failed. Please try again later.';
      });
      debugPrint('QuickExportModal._export error: $e');
    }
  }

  Future<void> _share() async {
    if (_successPath == null) return;
    await _service.shareFile(_successPath!);
  }

  // ════════════════════════════════════════════════════════════════════
  //  Build
  // ════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy');
    final periodLabel =
        '${dateFmt.format(widget.periodStart)} – ${dateFmt.format(widget.periodEnd)}';

    // Determine which data sections we're exporting
    final sections = <String>[];
    if (widget.engagementData != null) sections.add('Engagement Trends');
    if (widget.performanceData != null) sections.add('Performance Statistics');

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Drag handle ──────────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ───────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.file_download_outlined,
                  color: Colors.indigo[400], size: 24),
              const SizedBox(width: 8),
              Text(
                'Export Current View',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Download the data currently displayed on screen.',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          // ── Data summary card ────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryRow(Icons.person_outline, widget.childName),
                const SizedBox(height: 6),
                _summaryRow(Icons.date_range, periodLabel),
                const SizedBox(height: 6),
                _summaryRow(Icons.dashboard_outlined, sections.join(', ')),
                if (widget.filterSummary != null &&
                    widget.filterSummary!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _summaryRow(Icons.filter_list, widget.filterSummary!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Format picker ────────────────────────────────────
          Text(
            'Select File Format',
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700]),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _formatOption(
                format: ReportFormat.pdf,
                icon: Icons.picture_as_pdf,
                label: 'PDF',
                description: 'Formatted report with charts',
                color: Colors.red,
              ),
              const SizedBox(width: 12),
              _formatOption(
                format: ReportFormat.csv,
                icon: Icons.table_chart,
                label: 'CSV',
                description: 'Raw data for spreadsheets',
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Error message ────────────────────────────────────
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange[700], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Success notification ─────────────────────────────
          if (_successPath != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Report downloaded successfully',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[800]),
                        ),
                        Text(
                          _successPath!.split(Platform.pathSeparator).last,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.green[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.share, color: Colors.green[700], size: 20),
                    tooltip: 'Share',
                    onPressed: _share,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Action buttons ───────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _exporting ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child:
                      Text('Cancel', style: GoogleFonts.poppins(fontSize: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _exporting
                      ? null
                      : _successPath != null
                          ? _share
                          : _export,
                  icon: _exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(_successPath != null
                          ? Icons.share
                          : Icons.file_download),
                  label: Text(
                    _exporting
                        ? 'Exporting…'
                        : _successPath != null
                            ? 'Share Report'
                            : 'Download ${_format == ReportFormat.pdf ? 'PDF' : 'CSV'}',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    backgroundColor:
                        _successPath != null ? Colors.green : Colors.indigo,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── UI helpers ───────────────────────────────────────────────────────

  Widget _summaryRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.indigo.shade400),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
                fontSize: 12, color: Colors.indigo.shade700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _formatOption({
    required ReportFormat format,
    required IconData icon,
    required String label,
    required String description,
    required MaterialColor color,
  }) {
    final selected = _format == format;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _exporting ? null : () => setState(() => _format = format),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? color[50] : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color[400]! : Colors.grey[200]!,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 32, color: selected ? color[600] : Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: selected ? color[800] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: selected ? color[600] : Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
