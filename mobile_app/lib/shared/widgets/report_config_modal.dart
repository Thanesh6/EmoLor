import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/analytics_filter_params.dart';
import '../services/report_generation_service.dart';

/// UCD045 – Report Configuration Modal
///
/// A bottom-sheet modal that lets the user configure:
///  • Date range (preset or custom)
///  • Report format (PDF / CSV)
///  • Data sections to include (Engagement, Performance)
///
/// Calls [ReportGenerationService] to collect data, generate the
/// document, and optionally share it via the system share sheet.
class ReportConfigModal extends StatefulWidget {
  final String childId;
  final String childName;

  const ReportConfigModal({
    super.key,
    required this.childId,
    required this.childName,
  });

  /// Convenience launcher.
  static Future<void> show(
    BuildContext context, {
    required String childId,
    required String childName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReportConfigModal(
        childId: childId,
        childName: childName,
      ),
    );
  }

  @override
  State<ReportConfigModal> createState() => _ReportConfigModalState();
}

class _ReportConfigModalState extends State<ReportConfigModal> {
  final ReportGenerationService _service = ReportGenerationService();

  // Configuration state
  int _rangeIndex = 1; // 0=7d, 1=30d, 2=90d, 3=custom
  ReportFormat _format = ReportFormat.pdf;
  final Set<ReportSection> _sections = {
    ReportSection.engagement,
    ReportSection.performance,
  };

  // Custom date range
  DateTimeRange? _customRange;

  // UCD046 – filter params
  final Set<String> _activityTypes = {};
  final Set<String> _skillCategories = {};
  String? _statusFilter;

  // Generation state
  bool _generating = false;
  String? _errorMessage;
  String? _successPath;

  // ── Computed date range ──────────────────────────────────────────────

  static const _presets = [
    _RangePreset('Last 7 Days', 7),
    _RangePreset('Last 30 Days', 30),
    _RangePreset('Last 3 Months', 90),
    _RangePreset('Custom Range', 0),
  ];

  DateTimeRange _effectiveRange() {
    if (_rangeIndex == 3 && _customRange != null) return _customRange!;
    final days = _presets[_rangeIndex].days;
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: days - 1)),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  // ── Generate ─────────────────────────────────────────────────────────

  Future<void> _generate() async {
    if (_sections.isEmpty) {
      setState(() => _errorMessage = 'Select at least one data section.');
      return;
    }
    if (_rangeIndex == 3 && _customRange == null) {
      setState(() => _errorMessage = 'Please select a custom date range.');
      return;
    }

    setState(() {
      _generating = true;
      _errorMessage = null;
      _successPath = null;
    });

    try {
      final range = _effectiveRange();
      final payload = await _service.collectData(
        childId: widget.childId,
        childName: widget.childName,
        start: range.start,
        end: range.end,
        sections: _sections,
        activityTypes: _activityTypes.isEmpty ? null : _activityTypes,
        skillCategories: _skillCategories.isEmpty ? null : _skillCategories,
        statusFilter: _statusFilter,
      );

      // Alternative Flow – No Data in Range
      if (!payload.hasData) {
        if (!mounted) return;
        setState(() {
          _generating = false;
          _errorMessage =
              'No data found for this period. Please select a different range.';
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
        _generating = false;
        _successPath = filePath;
      });
    } catch (e) {
      if (!mounted) return;
      // Alternative Flow – Generation Timeout / Error
      setState(() {
        _generating = false;
        _errorMessage =
            'Report is taking longer than expected. Please try again.';
      });
      debugPrint('ReportConfigModal._generate error: $e');
    }
  }

  Future<void> _share() async {
    if (_successPath == null) return;
    await _service.shareFile(_successPath!);
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              Theme.of(context).colorScheme.copyWith(primary: Colors.indigo),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _rangeIndex = 3;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Build
  // ══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
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

            // Title
            Row(
              children: [
                Icon(Icons.description_outlined,
                    color: Colors.indigo[400], size: 24),
                const SizedBox(width: 8),
                Text(
                  'Export Report',
                  style: GoogleFonts.poppins(
                      fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Generate a downloadable report for ${widget.childName}',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // ── Date Range ──────────────────────────────────────────────
            _label('Date Range'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_presets.length, (i) {
                final isCustom = i == 3;
                final selected = _rangeIndex == i;
                String label = _presets[i].label;
                if (isCustom && _customRange != null) {
                  final fmt = DateFormat('MMM d');
                  label =
                      '${fmt.format(_customRange!.start)} – ${fmt.format(_customRange!.end)}';
                }
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) {
                    if (isCustom) {
                      _pickCustomRange();
                    } else {
                      setState(() {
                        _rangeIndex = i;
                        _errorMessage = null;
                      });
                    }
                  },
                  selectedColor: Colors.indigo[100],
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? Colors.indigo[800] : Colors.grey[700],
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // ── Report Format ───────────────────────────────────────────
            _label('Report Format'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ReportFormat>(
                segments: const [
                  ButtonSegment(
                    value: ReportFormat.pdf,
                    label: Text('PDF'),
                    icon: Icon(Icons.picture_as_pdf, size: 18),
                  ),
                  ButtonSegment(
                    value: ReportFormat.csv,
                    label: Text('CSV'),
                    icon: Icon(Icons.table_chart, size: 18),
                  ),
                ],
                selected: {_format},
                onSelectionChanged: (s) => setState(() => _format = s.first),
                style: SegmentedButton.styleFrom(
                  textStyle: GoogleFonts.poppins(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Data Sections ───────────────────────────────────────────
            _label('Data Sections'),
            const SizedBox(height: 8),
            _sectionToggle(
              icon: Icons.show_chart,
              color: Colors.indigo,
              title: 'Engagement Trends',
              subtitle: 'Activity frequency, usage time, completion rate',
              section: ReportSection.engagement,
            ),
            const SizedBox(height: 8),
            _sectionToggle(
              icon: Icons.radar,
              color: Colors.teal,
              title: 'Performance Statistics',
              subtitle: 'Accuracy, response time, skill mastery levels',
              section: ReportSection.performance,
            ),
            const SizedBox(height: 20),

            // ── Activity Type Filters (UCD046) ─────────────────────────
            _label('Activity Types'),
            const SizedBox(height: 4),
            Text(
              'Leave empty to include all types',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AnalyticsFilterParams.allActivityTypes.map((type) {
                final selected = _activityTypes.contains(type);
                return FilterChip(
                  label: Text(
                    AnalyticsFilterParams.allActivityTypeLabels[type] ?? type,
                  ),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      if (selected) {
                        _activityTypes.remove(type);
                      } else {
                        _activityTypes.add(type);
                      }
                    });
                  },
                  selectedColor: Colors.indigo[100],
                  checkmarkColor: Colors.indigo[800],
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    color: selected ? Colors.indigo[800] : Colors.grey[700],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Skill Category Filters (UCD046) ────────────────────────
            _label('Skill Categories'),
            const SizedBox(height: 4),
            Text(
              'Leave empty to include all categories',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AnalyticsFilterParams.allSkillCategories.map((cat) {
                final selected = _skillCategories.contains(cat);
                return FilterChip(
                  label: Text(cat[0].toUpperCase() + cat.substring(1)),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      if (selected) {
                        _skillCategories.remove(cat);
                      } else {
                        _skillCategories.add(cat);
                      }
                    });
                  },
                  selectedColor: Colors.teal[100],
                  checkmarkColor: Colors.teal[800],
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    color: selected ? Colors.teal[800] : Colors.grey[700],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Completion Status Filter (UCD046) ──────────────────────
            _label('Completion Status'),
            const SizedBox(height: 4),
            Text(
              'Leave unselected to include all statuses',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AnalyticsFilterParams.allStatuses.map((status) {
                final selected = _statusFilter == status;
                return ChoiceChip(
                  label: Text(status[0].toUpperCase() + status.substring(1)),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _statusFilter = selected ? null : status);
                  },
                  selectedColor: Colors.amber[100],
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    color: selected ? Colors.amber[900] : Colors.grey[700],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Error / Success ─────────────────────────────────────────
            if (_errorMessage != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

            if (_successPath != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green[700], size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Download Complete!',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[800]),
                          ),
                          Text(
                            _successPath!.split('/').last,
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: Colors.green[600]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon:
                          Icon(Icons.share, color: Colors.green[700], size: 20),
                      tooltip: 'Share',
                      onPressed: _share,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Generate / Close buttons ────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _generating ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child:
                        Text('Close', style: GoogleFonts.poppins(fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _generating
                        ? null
                        : _successPath != null
                            ? _share
                            : _generate,
                    icon: _generating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(_successPath != null
                            ? Icons.share
                            : Icons.download),
                    label: Text(
                      _generating
                          ? 'Generating…'
                          : _successPath != null
                              ? 'Share Report'
                              : 'Generate',
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
      ),
    );
  }

  // ── UI helpers ───────────────────────────────────────────────────────

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700]),
      );

  Widget _sectionToggle({
    required IconData icon,
    required MaterialColor color,
    required String title,
    required String subtitle,
    required ReportSection section,
  }) {
    final selected = _sections.contains(section);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          if (selected) {
            _sections.remove(section);
          } else {
            _sections.add(section);
          }
          _errorMessage = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color[50] : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color[300]! : Colors.grey[200]!,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? color[600] : Colors.grey[400], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? color[800] : Colors.grey[600])),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: selected ? color[600] : Colors.grey[400])),
                ],
              ),
            ),
            Checkbox(
              value: selected,
              onChanged: (_) {
                setState(() {
                  if (selected) {
                    _sections.remove(section);
                  } else {
                    _sections.add(section);
                  }
                  _errorMessage = null;
                });
              },
              activeColor: color[600],
            ),
          ],
        ),
      ),
    );
  }
}

class _RangePreset {
  final String label;
  final int days;
  const _RangePreset(this.label, this.days);
}
