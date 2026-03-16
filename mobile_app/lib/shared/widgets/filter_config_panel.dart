import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/analytics_filter_params.dart';

/// UCD046 – Filter Configuration Panel
///
/// A bottom-sheet panel that lets the user customise analytics criteria:
///  • Date range (preset chips + custom range picker)
///  • Activity types (game, exercise, story, art)
///  • Skill categories (Emotion Recognition, Social Cues, …)
///  • Completion status
///  • Comparison metric
///
/// Returns the updated [AnalyticsFilterParams] via [Navigator.pop].
class FilterConfigPanel extends StatefulWidget {
  final AnalyticsFilterParams current;

  const FilterConfigPanel({super.key, required this.current});

  /// Shows the filter panel as a modal bottom sheet and returns
  /// the updated params, or `null` if the user dismissed without
  /// applying.
  static Future<AnalyticsFilterParams?> show(
    BuildContext context, {
    required AnalyticsFilterParams current,
  }) {
    return showModalBottomSheet<AnalyticsFilterParams>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FilterConfigPanel(current: current),
    );
  }

  @override
  State<FilterConfigPanel> createState() => _FilterConfigPanelState();
}

class _FilterConfigPanelState extends State<FilterConfigPanel> {
  late int _rangePreset;
  late DateTime? _customStart;
  late DateTime? _customEnd;
  late Set<String> _activityTypes;
  late Set<String> _skillCategories;
  late String? _statusFilter;
  late ComparisonMetric _comparisonMetric;

  String? _validationError;

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    _rangePreset = c.rangePreset;
    _customStart = c.customStart;
    _customEnd = c.customEnd;
    _activityTypes = Set.of(c.activityTypes);
    _skillCategories = Set.of(c.skillCategories);
    _statusFilter = c.statusFilter;
    _comparisonMetric = c.comparisonMetric;
  }

  AnalyticsFilterParams _buildParams() => AnalyticsFilterParams(
        rangePreset: _rangePreset,
        customStart: _customStart,
        customEnd: _customEnd,
        activityTypes: _activityTypes,
        skillCategories: _skillCategories,
        statusFilter: _statusFilter,
        comparisonMetric: _comparisonMetric,
      );

  void _apply() {
    final params = _buildParams();
    final err = params.validate();
    if (err != null) {
      setState(() => _validationError = err);
      return;
    }
    Navigator.pop(context, params);
  }

  void _reset() {
    setState(() {
      _rangePreset = 1;
      _customStart = null;
      _customEnd = null;
      _activityTypes = {};
      _skillCategories = {};
      _statusFilter = null;
      _comparisonMetric = ComparisonMetric.accuracy;
      _validationError = null;
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 30)),
              end: DateTime.now(),
            ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              Theme.of(ctx).colorScheme.copyWith(primary: Colors.indigo),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = DateTime(
            picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        _rangePreset = 3;
        _validationError = null;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Build
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Icon(Icons.tune, color: Colors.indigo[400], size: 22),
                const SizedBox(width: 8),
                Text(
                  'Filter & Parameters',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _reset,
                  child: Text('Reset',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.red[400])),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Scrollable body
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  const SizedBox(height: 12),

                  // ── Date Range ────────────────────────────────────
                  _sectionLabel('Date Range'),
                  const SizedBox(height: 8),
                  _dateRangeChips(),
                  if (_rangePreset == 3) ...[
                    const SizedBox(height: 8),
                    _customDateRow(),
                  ],
                  const SizedBox(height: 20),

                  // ── Activity Types ────────────────────────────────
                  _sectionLabel('Activity Types'),
                  const SizedBox(height: 4),
                  Text(
                    'Filter by type of activity',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 8),
                  _activityTypeChips(),
                  const SizedBox(height: 20),

                  // ── Skill Categories ──────────────────────────────
                  _sectionLabel('Skill Categories'),
                  const SizedBox(height: 4),
                  Text(
                    'Filter performance by skill area',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 8),
                  _skillCategoryChips(),
                  const SizedBox(height: 20),

                  // ── Completion Status ─────────────────────────────
                  _sectionLabel('Completion Status'),
                  const SizedBox(height: 8),
                  _statusChips(),
                  const SizedBox(height: 20),

                  // ── Comparison Metric ─────────────────────────────
                  _sectionLabel('Comparison Metric'),
                  const SizedBox(height: 4),
                  Text(
                    'Primary metric for charts and KPIs',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 8),
                  _metricChips(),
                ],
              ),
            ),

            // Validation error
            if (_validationError != null) ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[600], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.poppins(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _validationError != null ? null : _apply,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text('Apply Filters',
                          style: GoogleFonts.poppins(fontSize: 14)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.indigo,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Section builders
  // ═══════════════════════════════════════════════════════════════════════

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700]),
      );

  // ── Date range ───────────────────────────────────────────────────────

  Widget _dateRangeChips() {
    const labels = ['Last 7 Days', 'Last 30 Days', 'Last 3 Months', 'Custom'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(4, (i) {
        final selected = _rangePreset == i;
        return ChoiceChip(
          label: Text(labels[i]),
          selected: selected,
          onSelected: (_) {
            if (i == 3) {
              _pickCustomRange();
            } else {
              setState(() {
                _rangePreset = i;
                _validationError = null;
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
    );
  }

  Widget _customDateRow() {
    final fmt = DateFormat('MMM d, yyyy');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.indigo[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.date_range, size: 18, color: Colors.indigo[400]),
          const SizedBox(width: 8),
          Text(
            _customStart != null && _customEnd != null
                ? '${fmt.format(_customStart!)} — ${fmt.format(_customEnd!)}'
                : 'Tap "Custom" to pick dates',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.indigo[700]),
          ),
          const Spacer(),
          InkWell(
            onTap: _pickCustomRange,
            child: Text('Change',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo)),
          ),
        ],
      ),
    );
  }

  // ── Activity types ───────────────────────────────────────────────────

  Widget _activityTypeChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AnalyticsFilterParams.allActivityTypes.map((type) {
        final selected = _activityTypes.contains(type);
        final label = AnalyticsFilterParams.allActivityTypeLabels[type] ?? type;
        return FilterChip(
          label: Text(label),
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
          selectedColor: Colors.blue[100],
          avatar: Icon(_activityIcon(type),
              size: 16, color: selected ? Colors.blue[700] : Colors.grey[500]),
          labelStyle: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.blue[800] : Colors.grey[700],
          ),
        );
      }).toList(),
    );
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'game':
        return Icons.sports_esports;
      case 'exercise':
        return Icons.fitness_center;
      case 'story':
        return Icons.auto_stories;
      case 'art':
        return Icons.palette;
      default:
        return Icons.extension;
    }
  }

  // ── Skill categories ─────────────────────────────────────────────────

  Widget _skillCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AnalyticsFilterParams.allSkillCategories.map((cat) {
        final selected = _skillCategories.contains(cat);
        return FilterChip(
          label: Text(cat),
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
          labelStyle: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.teal[800] : Colors.grey[700],
          ),
        );
      }).toList(),
    );
  }

  // ── Completion status ────────────────────────────────────────────────

  Widget _statusChips() {
    const statuses = [null, 'completed', 'started'];
    const labels = ['All', 'Completed Only', 'Started Only'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(3, (i) {
        final selected = _statusFilter == statuses[i];
        return ChoiceChip(
          label: Text(labels[i]),
          selected: selected,
          onSelected: (_) {
            setState(() {
              _statusFilter = statuses[i];
            });
          },
          selectedColor: Colors.orange[100],
          labelStyle: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.orange[800] : Colors.grey[700],
          ),
        );
      }),
    );
  }

  // ── Comparison metric ────────────────────────────────────────────────

  Widget _metricChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ComparisonMetric.values.map((m) {
        final selected = _comparisonMetric == m;
        return ChoiceChip(
          label: Text(m.label),
          selected: selected,
          onSelected: (_) {
            setState(() => _comparisonMetric = m);
          },
          selectedColor: Colors.deepPurple[100],
          labelStyle: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.deepPurple[800] : Colors.grey[700],
          ),
        );
      }).toList(),
    );
  }
}
