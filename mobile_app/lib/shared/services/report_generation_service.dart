import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'engagement_analytics_service.dart';
import 'performance_stats_service.dart';

/// UCD045 – Generate Reports
///
/// Aggregates engagement and performance data for a child and renders
/// the result as either a formatted PDF document or a CSV spreadsheet.
/// The file is saved to the device and optionally shared via the
/// system share sheet.
class ReportGenerationService {
  final EngagementAnalyticsService _engagementService =
      EngagementAnalyticsService();
  final PerformanceStatsService _performanceService = PerformanceStatsService();

  /// Collects all data needed for the report.
  ///
  /// Optional [activityTypes], [skillCategories], and [statusFilter] narrow
  /// the dataset that feeds into the report (UCD046).
  Future<ReportPayload> collectData({
    required String childId,
    required String childName,
    required DateTime start,
    required DateTime end,
    required Set<ReportSection> sections,
    Set<String>? activityTypes,
    Set<String>? skillCategories,
    String? statusFilter,
  }) async {
    EngagementData? engagement;
    PerformanceData? performance;

    if (sections.contains(ReportSection.engagement)) {
      engagement = await _engagementService.getEngagement(
        childId: childId,
        start: start,
        end: end,
        activityTypes: activityTypes,
        statusFilter: statusFilter,
      );
    }
    if (sections.contains(ReportSection.performance)) {
      performance = await _performanceService.getPerformance(
        childId: childId,
        start: start,
        end: end,
        activityTypes: activityTypes,
        skillCategories: skillCategories,
        statusFilter: statusFilter,
      );
    }

    final hasData = (engagement != null && !engagement.isEmpty) ||
        (performance != null && !performance.isEmpty);

    return ReportPayload(
      childName: childName,
      start: start,
      end: end,
      engagement: engagement,
      performance: performance,
      hasData: hasData,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PDF Generation
  // ═══════════════════════════════════════════════════════════════════════

  /// Generates a styled PDF and returns the file path.
  Future<String> generatePdf(ReportPayload payload) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
      ),
    );

    final dateFmt = DateFormat('MMM d, yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => _pdfHeader(payload, dateFmt, ctx),
        footer: (ctx) => _pdfFooter(ctx),
        build: (ctx) {
          final widgets = <pw.Widget>[];

          // Engagement section
          if (payload.engagement != null && !payload.engagement!.isEmpty) {
            widgets.addAll(_pdfEngagementSection(payload.engagement!, dateFmt));
          }

          // Performance section
          if (payload.performance != null && !payload.performance!.isEmpty) {
            if (widgets.isNotEmpty) widgets.add(pw.SizedBox(height: 16));
            widgets.addAll(_pdfPerformanceSection(payload.performance!));
          }

          if (widgets.isEmpty) {
            widgets.add(pw.Center(
              child: pw.Text(
                'No data found for the selected date range.',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey600,
                ),
              ),
            ));
          }

          return widgets;
        },
      ),
    );

    final bytes = await pdf.save();
    return _saveFile(bytes, _fileName(payload, 'pdf'));
  }

  // ── PDF sections ─────────────────────────────────────────────────────

  pw.Widget _pdfHeader(ReportPayload p, DateFormat fmt, pw.Context ctx) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('EmoLor Progress Report',
                style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text('Child: ${p.childName}',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.Text('Period: ${fmt.format(p.start)} – ${fmt.format(p.end)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Text('Generated: ${fmt.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1, color: PdfColors.indigo200),
        pw.SizedBox(height: 12),
      ],
    );
  }

  pw.Widget _pdfFooter(pw.Context ctx) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'EmoLor – Emotional Learning for Children  •  Confidential',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400),
      ),
    );
  }

  List<pw.Widget> _pdfEngagementSection(EngagementData data, DateFormat fmt) {
    return [
      _sectionHeading('Engagement Summary'),
      pw.SizedBox(height: 8),
      _kpiTable([
        ['Total Sessions', '${data.totalSessions}'],
        ['Completed', '${data.totalCompleted}'],
        ['Completion Rate', '${data.completionRate}%'],
        ['Avg Daily Time', '${data.avgDailyMinutes} min'],
        ['Total Time', '${data.totalMinutes} min'],
      ]),
      pw.SizedBox(height: 12),

      // Top Activities
      if (data.topActivities.isNotEmpty) ...[
        _subHeading('Top Activities'),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo400),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellAlignment: pw.Alignment.centerLeft,
          headerAlignment: pw.Alignment.centerLeft,
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          headers: ['Activity', 'Type', 'Sessions'],
          data: data.topActivities
              .map((a) => [a.title, a.activityType, '${a.count}'])
              .toList(),
        ),
        pw.SizedBox(height: 12),
      ],

      // Recent Activity Detail
      if (data.dataPoints.isNotEmpty) ...[
        _subHeading('Recent Activity Details (last 20)'),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo400),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          headers: [
            'Date',
            'Activity',
            'Duration',
            'Status',
            'Score',
            'Completed %'
          ],
          data: data.dataPoints.take(20).map((dp) {
            final dur = dp.durationSecs >= 60
                ? '${(dp.durationSecs / 60).round()} min'
                : '${dp.durationSecs}s';
            return [
              fmt.format(dp.date),
              dp.activityTitle,
              dur,
              dp.status,
              dp.score?.toString() ?? '—',
              '${dp.completionPct}%',
            ];
          }).toList(),
        ),
      ],
    ];
  }

  List<pw.Widget> _pdfPerformanceSection(PerformanceData data) {
    return [
      _sectionHeading('Performance Statistics'),
      pw.SizedBox(height: 8),
      _kpiTable([
        ['Overall Accuracy', '${data.overallAccuracy}%'],
        [
          'Avg Response Time',
          data.overallResponseTimeMs > 0
              ? '${(data.overallResponseTimeMs / 1000).toStringAsFixed(1)}s'
              : '—'
        ],
        ['Adaptive Level', data.levelLabel],
        ['Total Sessions', '${data.totalSessions}'],
        ['Completed', '${data.totalCompleted}'],
      ]),
      pw.SizedBox(height: 12),

      // Per-category breakdown
      if (data.categoryStats.isNotEmpty) ...[
        _subHeading('Skill Category Breakdown'),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.teal400),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          headers: [
            'Category',
            'Sessions',
            'Completed',
            'Accuracy',
            'Avg Response',
            'Level'
          ],
          data: data.categoryStats.entries.map((e) {
            final cs = e.value;
            return [
              cs.category,
              '${cs.totalSessions}',
              '${cs.completedSessions}',
              '${cs.accuracyRate}%',
              cs.responseTimeFormatted,
              '${cs.currentLevel}',
            ];
          }).toList(),
        ),
      ],
    ];
  }

  // ── PDF helpers ──────────────────────────────────────────────────────

  pw.Widget _sectionHeading(String text) => pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.indigo700,
        ),
      );

  pw.Widget _subHeading(String text) => pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey800,
        ),
      );

  pw.Widget _kpiTable(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
      },
      children: rows.map((r) {
        return pw.TableRow(children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(r[0],
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(r[1], style: const pw.TextStyle(fontSize: 10)),
          ),
        ]);
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  CSV Generation
  // ═══════════════════════════════════════════════════════════════════════

  /// Generates a CSV file with tabulated data and returns the file path.
  Future<String> generateCsv(ReportPayload payload) async {
    final rows = <List<String>>[];

    // Header metadata
    rows.add(['EmoLor Progress Report']);
    rows.add([
      'Child',
      payload.childName,
      'Period',
      DateFormat('yyyy-MM-dd').format(payload.start),
      DateFormat('yyyy-MM-dd').format(payload.end),
    ]);
    rows.add([]);

    // Engagement data
    if (payload.engagement != null && !payload.engagement!.isEmpty) {
      final e = payload.engagement!;
      rows.add(['=== ENGAGEMENT SUMMARY ===']);
      rows.add(['Metric', 'Value']);
      rows.add(['Total Sessions', '${e.totalSessions}']);
      rows.add(['Completed', '${e.totalCompleted}']);
      rows.add(['Completion Rate (%)', '${e.completionRate}']);
      rows.add(['Avg Daily Time (min)', '${e.avgDailyMinutes}']);
      rows.add(['Total Time (min)', '${e.totalMinutes}']);
      rows.add([]);

      // Top activities
      rows.add(['=== TOP ACTIVITIES ===']);
      rows.add(['Activity', 'Type', 'Sessions']);
      for (final a in e.topActivities) {
        rows.add([a.title, a.activityType, '${a.count}']);
      }
      rows.add([]);

      // Activity detail
      rows.add(['=== ACTIVITY DETAILS ===']);
      rows.add([
        'Date',
        'Activity',
        'Type',
        'Duration (sec)',
        'Status',
        'Score',
        'Completion %'
      ]);
      for (final dp in e.dataPoints) {
        rows.add([
          DateFormat('yyyy-MM-dd HH:mm').format(dp.date),
          dp.activityTitle,
          dp.activityType,
          '${dp.durationSecs}',
          dp.status,
          dp.score?.toString() ?? '',
          '${dp.completionPct}',
        ]);
      }
      rows.add([]);
    }

    // Performance data
    if (payload.performance != null && !payload.performance!.isEmpty) {
      final p = payload.performance!;
      rows.add(['=== PERFORMANCE SUMMARY ===']);
      rows.add(['Metric', 'Value']);
      rows.add(['Overall Accuracy (%)', '${p.overallAccuracy}']);
      rows.add(['Avg Response Time (ms)', '${p.overallResponseTimeMs}']);
      rows.add(['Adaptive Level', '${p.currentLevel}']);
      rows.add(['Total Sessions', '${p.totalSessions}']);
      rows.add(['Completed', '${p.totalCompleted}']);
      rows.add([]);

      // Category breakdown
      rows.add(['=== SKILL CATEGORY BREAKDOWN ===']);
      rows.add([
        'Category',
        'Sessions',
        'Completed',
        'Accuracy (%)',
        'Avg Response (ms)',
        'Level'
      ]);
      for (final cs in p.categoryStats.values) {
        rows.add([
          cs.category,
          '${cs.totalSessions}',
          '${cs.completedSessions}',
          '${cs.accuracyRate}',
          '${cs.avgResponseTimeMs}',
          '${cs.currentLevel}',
        ]);
      }
      rows.add([]);

      // Per-category timelines
      for (final cs in p.categoryStats.values) {
        if (cs.timeline.isEmpty) continue;
        rows.add(['=== ${cs.category.toUpperCase()} DETAIL ===']);
        rows.add([
          'Date',
          'Activity',
          'Accuracy (%)',
          'Response (ms)',
          'Difficulty Level',
          'Status',
          'Score'
        ]);
        for (final pt in cs.timeline) {
          rows.add([
            DateFormat('yyyy-MM-dd HH:mm').format(pt.date),
            pt.activityTitle,
            '${pt.accuracyPct}',
            '${pt.responseTimeMs}',
            '${pt.difficultyLevel}',
            pt.status,
            pt.score?.toString() ?? '',
          ]);
        }
        rows.add([]);
      }
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final bytes = Uint8List.fromList(csvString.codeUnits);
    return _saveFile(bytes, _fileName(payload, 'csv'));
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  File helpers
  // ═══════════════════════════════════════════════════════════════════════

  String _fileName(ReportPayload payload, String ext) {
    final safeName = payload.childName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final dateSuffix = DateFormat('yyyyMMdd').format(DateTime.now());
    return 'EmoLor_Report_${safeName}_$dateSuffix.$ext';
  }

  Future<String> _saveFile(Uint8List bytes, String fileName) async {
    Directory targetDir;

    if (!kIsWeb && Platform.isAndroid) {
      targetDir = Directory('/storage/emulated/0/Download');
      if (!await targetDir.exists()) {
        targetDir = await getApplicationDocumentsDirectory();
      }
    } else if (!kIsWeb && Platform.isIOS) {
      targetDir = await getApplicationDocumentsDirectory();
    } else {
      targetDir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    }

    final filePath = '${targetDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }

  /// Opens the system share sheet for the generated file.
  Future<void> shareFile(String filePath) async {
    await Share.shareXFiles([XFile(filePath)]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Data classes ─────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

/// Configurable sections that may be included in the report.
enum ReportSection { engagement, performance }

/// Report format.
enum ReportFormat { pdf, csv }

@immutable
class ReportPayload {
  final String childName;
  final DateTime start;
  final DateTime end;
  final EngagementData? engagement;
  final PerformanceData? performance;
  final bool hasData;

  const ReportPayload({
    required this.childName,
    required this.start,
    required this.end,
    this.engagement,
    this.performance,
    required this.hasData,
  });
}
