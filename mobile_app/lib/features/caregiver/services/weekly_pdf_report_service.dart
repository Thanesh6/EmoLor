import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Goal entry as supplied to the PDF builder.
@immutable
class PdfGoalEntry {
  final String label;
  final int current;
  final int target;
  final String emoji;
  const PdfGoalEntry({
    required this.label,
    required this.current,
    required this.target,
    this.emoji = '🎯',
  });
}

/// Reward entry as supplied to the PDF builder.
@immutable
class PdfRewardEntry {
  final String title;
  final String emoji;
  final bool unlocked;
  const PdfRewardEntry({
    required this.title,
    required this.emoji,
    required this.unlocked,
  });
}

/// Single immutable bundle that fully describes a weekly PDF report.
/// All chart data here is already filtered/scoped — the PDF builder
/// does not query Supabase or read SharedPreferences.
@immutable
class WeeklyPdfReportPayload {
  final String childName;
  final int? childAge;
  final String weekRangeLabel; // e.g. "20/04/2026 – 26/04/2026"
  final String weekShortLabel; // e.g. "This Week" / "Last Week"

  // Chart 1 — Emotion Distribution
  final Map<String, int> emotionFreq;

  // Chart 2 — Emotion Trend (per-day Sun..Sat)
  final List<int> positivePerDay;
  final List<int> negativePerDay;

  // Chart 3 — Goals
  final List<PdfGoalEntry> goals;

  // Chart 4 — Rewards
  final List<PdfRewardEntry> rewards;
  final int rewardsUnlocked;
  final int rewardsTotal;

  /// Optional pre-generated AI summary. When null/empty, the PDF
  /// builder falls back to a deterministic summary built from the
  /// chart numbers above.
  final String? aiSummary;

  /// True when every dataset is empty — drives the empty-state copy.
  bool get isEmpty =>
      emotionFreq.values.every((v) => v == 0) &&
      positivePerDay.every((v) => v == 0) &&
      negativePerDay.every((v) => v == 0) &&
      goals.every((g) => g.current == 0) &&
      rewardsUnlocked == 0;

  const WeeklyPdfReportPayload({
    required this.childName,
    required this.childAge,
    required this.weekRangeLabel,
    required this.weekShortLabel,
    required this.emotionFreq,
    required this.positivePerDay,
    required this.negativePerDay,
    required this.goals,
    required this.rewards,
    required this.rewardsUnlocked,
    required this.rewardsTotal,
    this.aiSummary,
  });
}

/// Builds and shares a clean, brand-consistent A4 PDF from the
/// supplied payload. Uses `pdf` + `printing` packages — every chart
/// is drawn as native PDF widgets (no screenshots), so the output
/// is crisp and never overflows.
class WeeklyPdfReportService {
  WeeklyPdfReportService._();

  /// Brand colours (kept in sync with the in-app analytics dashboard).
  static const _primaryPurple = PdfColor.fromInt(0xFF6B21A8);
  static const _accentPurple = PdfColor.fromInt(0xFFC026D3);
  static const _bgLavender = PdfColor.fromInt(0xFFFDF4FF);
  static const _bgSurface = PdfColor.fromInt(0xFFF9FAFB);
  static const _greenPositive = PdfColor.fromInt(0xFF10B981);
  static const _redNegative = PdfColor.fromInt(0xFFEF4444);
  static const _amber = PdfColor.fromInt(0xFFF59E0B);
  static const _grey300 = PdfColor.fromInt(0xFFE5E7EB);
  static const _grey500 = PdfColor.fromInt(0xFF6B7280);
  static const _grey700 = PdfColor.fromInt(0xFF374151);

  /// Build the PDF and hand it off to the system share / print sheet.
  static Future<void> generate(WeeklyPdfReportPayload p) async {
    final doc = pw.Document(
      title: '${p.childName} – EMOLOR Weekly Report',
      author: 'EMOLOR',
    );

    final generatedAt = _fmtDateTime(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 30),
        build: (ctx) => [
          _buildHeader(p, generatedAt),
          pw.SizedBox(height: 18),
          if (p.isEmpty) _buildEmptyState(p) else ..._buildBodySections(p),
        ],
      ),
    );

    // Use Printing.sharePdf so the user gets the system share sheet
    // (open / save / share to Gmail / Drive / etc) on Android.
    final bytes = await doc.save();
    final safeName = p.childName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final filename = '${safeName}_EMOLOR_Report_${_fileTag(DateTime.now())}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  // ── Header ───────────────────────────────────────────────────────
  static pw.Widget _buildHeader(WeeklyPdfReportPayload p, String generatedAt) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: _bgLavender,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: _accentPurple, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'EMOLOR',
            style: pw.TextStyle(
              fontSize: 32,
              fontWeight: pw.FontWeight.bold,
              color: _primaryPurple,
              letterSpacing: 4,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Weekly Emotion & Progress Report',
            style: pw.TextStyle(
              fontSize: 13,
              color: _accentPurple,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Container(height: 0.8, color: _grey300),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _metaCol('Child', p.childName),
              _metaCol('Age', p.childAge == null ? '—' : '${p.childAge}'),
              _metaCol('Week', p.weekRangeLabel),
              _metaCol('Generated', generatedAt),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _metaCol(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label.toUpperCase(),
            style: pw.TextStyle(
                fontSize: 8,
                color: _grey500,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 11,
                color: _grey700,
                fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  // ── Empty state (used when isEmpty is true) ──────────────────────
  static pw.Widget _buildEmptyState(WeeklyPdfReportPayload p) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(36),
      decoration: pw.BoxDecoration(
        color: _bgSurface,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: _grey300),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'No analytics data available for this selected week.',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 14,
              color: _grey700,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Once ${p.childName} starts using EMOLOR during ${p.weekShortLabel.toLowerCase()}, '
            'their emotional and activity data will appear here.',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 11, color: _grey500),
          ),
        ],
      ),
    );
  }

  // ── Body — 4 charts + summary ────────────────────────────────────
  static List<pw.Widget> _buildBodySections(WeeklyPdfReportPayload p) {
    return [
      _chartCard(
        title: '1. Emotion Distribution Chart',
        subtitle: 'How often each emotion was logged this week.',
        body: _emotionDistributionChart(p),
      ),
      pw.SizedBox(height: 14),
      _chartCard(
        title: '2. Emotion Trend Chart',
        subtitle: 'Positive vs negative emotions across the week.',
        body: _emotionTrendChart(p),
      ),
      pw.SizedBox(height: 14),
      _chartCard(
        title: '3. Goals Progress Chart',
        subtitle: 'How close each active goal is to completion.',
        body: _goalsProgressChart(p),
      ),
      pw.SizedBox(height: 14),
      _chartCard(
        title: '4. Rewards Progress Chart',
        subtitle: 'Rewards unlocked and waiting in the gallery.',
        body: _rewardsProgressChart(p),
      ),
      pw.SizedBox(height: 18),
      _summarySection(p),
    ];
  }

  static pw.Widget _chartCard({
    required String title,
    required String subtitle,
    required pw.Widget body,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryPurple)),
          pw.SizedBox(height: 2),
          pw.Text(subtitle,
              style: const pw.TextStyle(fontSize: 9, color: _grey500)),
          pw.SizedBox(height: 12),
          body,
        ],
      ),
    );
  }

  // ── Chart 1 — emotion distribution (horizontal bars + %) ─────────
  static pw.Widget _emotionDistributionChart(WeeklyPdfReportPayload p) {
    final entries = p.emotionFreq.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return _emptyChartPlaceholder('No emotion entries this week.');
    }
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    return pw.Column(
      children: entries.map((e) {
        final pct = e.value / total;
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 80,
                child: pw.Text(e.key,
                    style: const pw.TextStyle(fontSize: 10, color: _grey700)),
              ),
              pw.Expanded(
                child: pw.Stack(
                  children: [
                    pw.Container(
                      height: 12,
                      decoration: pw.BoxDecoration(
                        color: _grey300,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                    ),
                    pw.LayoutBuilder(
                      builder: (ctx, constraints) {
                        final w = (constraints?.maxWidth ?? 200) *
                            pct.clamp(0.02, 1.0);
                        return pw.Container(
                          width: w,
                          height: 12,
                          decoration: pw.BoxDecoration(
                            color: _emotionColor(e.key),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 8),
              pw.SizedBox(
                width: 56,
                child: pw.Text(
                  '${e.value}× (${(pct * 100).toStringAsFixed(0)}%)',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontSize: 9,
                      color: _grey700,
                      fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Chart 2 — emotion trend (paired vertical bars per day) ───────
  static pw.Widget _emotionTrendChart(WeeklyPdfReportPayload p) {
    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final hasAny = p.positivePerDay.any((v) => v > 0) ||
        p.negativePerDay.any((v) => v > 0);
    if (!hasAny) {
      return _emptyChartPlaceholder('No emotion entries logged this week.');
    }
    // Y-axis max: at least 4 so a single-entry day still looks like a bar.
    final maxVal = [
      ...p.positivePerDay,
      ...p.negativePerDay
    ].fold<int>(0, (m, v) => v > m ? v : m);
    final yMax = maxVal < 4 ? 4 : maxVal;
    const chartHeight = 110.0;

    pw.Widget bar(int v, PdfColor c) {
      final h = chartHeight * (v / yMax);
      return pw.Container(
        width: 8,
        height: h.clamp(0, chartHeight).toDouble(),
        decoration: pw.BoxDecoration(
          color: c,
          borderRadius: const pw.BorderRadius.only(
            topLeft: pw.Radius.circular(2),
            topRight: pw.Radius.circular(2),
          ),
        ),
      );
    }

    return pw.Column(
      children: [
        pw.Container(
          height: chartHeight,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4),
          decoration: pw.BoxDecoration(
            color: _bgSurface,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              return pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      bar(p.positivePerDay[i], _greenPositive),
                      pw.SizedBox(width: 2),
                      bar(p.negativePerDay[i], _redNegative),
                    ],
                  ),
                ],
              );
            }),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: labels
              .map((l) => pw.Text(l,
                  style: const pw.TextStyle(fontSize: 8, color: _grey500)))
              .toList(),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            _legendDot(_greenPositive, 'Positive'),
            pw.SizedBox(width: 16),
            _legendDot(_redNegative, 'Negative'),
          ],
        ),
      ],
    );
  }

  static pw.Widget _legendDot(PdfColor c, String label) {
    return pw.Row(children: [
      pw.Container(
        width: 8,
        height: 8,
        decoration: pw.BoxDecoration(color: c, shape: pw.BoxShape.circle),
      ),
      pw.SizedBox(width: 4),
      pw.Text(label,
          style: const pw.TextStyle(fontSize: 8, color: _grey700)),
    ]);
  }

  // ── Chart 3 — goals progress ─────────────────────────────────────
  static pw.Widget _goalsProgressChart(WeeklyPdfReportPayload p) {
    if (p.goals.isEmpty) {
      return _emptyChartPlaceholder('No active goals for this week.');
    }
    return pw.Column(
      children: p.goals.map((g) {
        final pct = g.target == 0
            ? 0.0
            : (g.current / g.target).clamp(0.0, 1.0).toDouble();
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${g.emoji}  ${g.label}',
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _grey700)),
                  pw.Text('${g.current} / ${g.target}',
                      style: pw.TextStyle(
                          fontSize: 9,
                          color: _grey500,
                          fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Stack(
                children: [
                  pw.Container(
                    height: 10,
                    decoration: pw.BoxDecoration(
                      color: _grey300,
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                  ),
                  pw.LayoutBuilder(
                    builder: (ctx, constraints) {
                      final w = (constraints?.maxWidth ?? 200) *
                          pct.clamp(0.02, 1.0);
                      return pw.Container(
                        width: w,
                        height: 10,
                        decoration: pw.BoxDecoration(
                          color: pct >= 1.0 ? _greenPositive : _accentPurple,
                          borderRadius: pw.BorderRadius.circular(5),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Chart 4 — rewards progress ───────────────────────────────────
  static pw.Widget _rewardsProgressChart(WeeklyPdfReportPayload p) {
    if (p.rewardsTotal == 0 && p.rewards.isEmpty) {
      return _emptyChartPlaceholder('No rewards configured for this profile.');
    }
    final total = p.rewardsTotal == 0
        ? (p.rewards.isEmpty ? 1 : p.rewards.length)
        : p.rewardsTotal;
    final pct = (p.rewardsUnlocked / total).clamp(0.0, 1.0).toDouble();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Unlocked',
                style: pw.TextStyle(
                    fontSize: 10,
                    color: _grey700,
                    fontWeight: pw.FontWeight.bold)),
            pw.Text('${p.rewardsUnlocked} / $total',
                style: pw.TextStyle(
                    fontSize: 10,
                    color: _amber,
                    fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Stack(
          children: [
            pw.Container(
              height: 14,
              decoration: pw.BoxDecoration(
                color: _grey300,
                borderRadius: pw.BorderRadius.circular(7),
              ),
            ),
            pw.LayoutBuilder(
              builder: (ctx, constraints) {
                final w = (constraints?.maxWidth ?? 200) *
                    pct.clamp(0.02, 1.0);
                return pw.Container(
                  width: w,
                  height: 14,
                  decoration: pw.BoxDecoration(
                    color: _amber,
                    borderRadius: pw.BorderRadius.circular(7),
                  ),
                );
              },
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        if (p.rewards.isNotEmpty)
          pw.Wrap(
            spacing: 6,
            runSpacing: 6,
            children: p.rewards
                .take(12)
                .map((r) => pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: r.unlocked
                            ? _amber.shade(0.15)
                            : _grey300.shade(0.4),
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(
                            color: r.unlocked ? _amber : _grey300, width: 0.5),
                      ),
                      child: pw.Text(
                        '${r.emoji}  ${r.title}${r.unlocked ? ' ✓' : ''}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: r.unlocked ? _grey700 : _grey500,
                          fontWeight: r.unlocked
                              ? pw.FontWeight.bold
                              : pw.FontWeight.normal,
                        ),
                      ),
                    ))
                .toList(),
          ),
      ],
    );
  }

  // ── Summary ──────────────────────────────────────────────────────
  static pw.Widget _summarySection(WeeklyPdfReportPayload p) {
    final summary = p.aiSummary != null && p.aiSummary!.trim().isNotEmpty
        ? p.aiSummary!.trim()
        : _autoSummary(p);
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _bgLavender,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _accentPurple, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Weekly Summary',
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryPurple)),
          pw.SizedBox(height: 8),
          pw.Text(
            summary,
            style: const pw.TextStyle(
                fontSize: 11, color: _grey700, lineSpacing: 1.4),
          ),
        ],
      ),
    );
  }

  /// Deterministic, parent-friendly summary used when no AI summary
  /// has been generated yet. Stays grounded in the supplied numbers.
  static String _autoSummary(WeeklyPdfReportPayload p) {
    final pos = p.positivePerDay.fold<int>(0, (s, v) => s + v);
    final neg = p.negativePerDay.fold<int>(0, (s, v) => s + v);
    final emotionTotal = pos + neg;
    final goalsCompleted =
        p.goals.where((g) => g.target > 0 && g.current >= g.target).length;
    final hasAnyData = emotionTotal > 0 ||
        p.goals.any((g) => g.current > 0) ||
        p.rewardsUnlocked > 0;

    if (!hasAnyData) {
      return 'No analytics data available for this selected week. Encourage '
          '${p.childName} to log a session in EMOLOR — once they do, this '
          'report will start filling in automatically.';
    }

    final buf = StringBuffer();
    if (emotionTotal > 0) {
      if (pos >= neg) {
        buf.write(
            '${p.childName} logged $pos positive and $neg negative emotion entries this week — a mostly upbeat pattern. ');
      } else {
        buf.write(
            '${p.childName} logged $neg negative and $pos positive emotion entries this week. Worth a gentle check-in. ');
      }
    }
    if (p.goals.isNotEmpty) {
      buf.write(goalsCompleted > 0
          ? '$goalsCompleted of ${p.goals.length} active goal${p.goals.length == 1 ? '' : 's'} were completed. '
          : '${p.goals.length} goal${p.goals.length == 1 ? ' is' : 's are'} still in progress. ');
    }
    if (p.rewardsUnlocked > 0 && p.rewardsTotal > 0) {
      buf.write(
          '${p.rewardsUnlocked} of ${p.rewardsTotal} rewards have been unlocked so far. ');
    }
    buf.write('Keep up the great work!');
    return buf.toString();
  }

  // ── Helpers ──────────────────────────────────────────────────────
  static pw.Widget _emptyChartPlaceholder(String msg) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 14),
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: _bgSurface,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _grey300),
      ),
      child: pw.Text(msg,
          style: const pw.TextStyle(fontSize: 10, color: _grey500)),
    );
  }

  static PdfColor _emotionColor(String name) {
    switch (name) {
      case 'Happy':
      case 'Joy':
      case 'Silly':
        return const PdfColor.fromInt(0xFFFBBF24);
      case 'Sad':
      case 'Sadness':
        return const PdfColor.fromInt(0xFF60A5FA);
      case 'Angry':
      case 'Anger':
        return const PdfColor.fromInt(0xFFEF4444);
      case 'Calm':
      case 'Trust':
        return const PdfColor.fromInt(0xFF14B8A6);
      case 'Excited':
      case 'Anticipation':
        return const PdfColor.fromInt(0xFFF97316);
      case 'Scared':
      case 'Fear':
        return const PdfColor.fromInt(0xFF9B5DE5);
      case 'Surprised':
      case 'Surprise':
        return const PdfColor.fromInt(0xFFEC4899);
      case 'Disgusted':
      case 'Disgust':
        return const PdfColor.fromInt(0xFF78716C);
      case 'Loved':
      case 'Love':
        return const PdfColor.fromInt(0xFFEC4899);
      case 'Proud':
        return const PdfColor.fromInt(0xFF22C55E);
      case 'Tired':
        return const PdfColor.fromInt(0xFF94A3B8);
      case 'Confused':
        return const PdfColor.fromInt(0xFF8B5CF6);
      default:
        return _accentPurple;
    }
  }

  static String _fmtDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  static String _fileTag(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}${two(dt.month)}${two(dt.day)}_${two(dt.hour)}${two(dt.minute)}';
  }
}
