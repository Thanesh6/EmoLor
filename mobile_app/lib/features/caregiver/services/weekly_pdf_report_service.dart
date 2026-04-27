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
  const PdfGoalEntry({
    required this.label,
    required this.current,
    required this.target,
  });
}

/// One bar of the Emotion Color Association chart — the child paired
/// [emotion] with the colour [hex] this many times during the week.
@immutable
class PdfColorAssocBar {
  final String emotion;
  final String hex; // '#RRGGBB' or '#AARRGGBB'
  final int count;
  const PdfColorAssocBar({
    required this.emotion,
    required this.hex,
    required this.count,
  });
}

/// Single immutable bundle that fully describes a weekly PDF report.
/// All chart data here is already filtered/scoped — the PDF builder
/// does not query Supabase or read SharedPreferences.
@immutable
class WeeklyPdfReportPayload {
  final String childName;
  final int? childAge;
  final String weekRangeLabel; // e.g. "20/04/2026 - 26/04/2026"
  final String weekShortLabel; // e.g. "This Week" / "Last Week"

  // Chart 1 — Emotion Distribution
  final Map<String, int> emotionFreq;

  // Chart 2 — Emotion Trend (Pre vs Post session, per day Sun..Sat)
  final List<int> prePerDay;
  final List<int> postPerDay;
  // Per-emotion freq used by the summary section.
  final Map<String, int> preEmotionFreq;
  final Map<String, int> postEmotionFreq;

  // Chart 3 — Emotion Color Association
  final List<PdfColorAssocBar> colorAssoc;

  // Chart 4 — Goals
  final List<PdfGoalEntry> goals;

  /// Optional pre-generated AI summary. When null/empty, the PDF
  /// builder falls back to a deterministic summary built from the
  /// chart numbers above.
  final String? aiSummary;

  /// True when every dataset is empty — drives the empty-state copy.
  bool get isEmpty =>
      emotionFreq.values.every((v) => v == 0) &&
      prePerDay.every((v) => v == 0) &&
      postPerDay.every((v) => v == 0) &&
      colorAssoc.isEmpty &&
      goals.every((g) => g.current == 0);

  const WeeklyPdfReportPayload({
    required this.childName,
    required this.childAge,
    required this.weekRangeLabel,
    required this.weekShortLabel,
    required this.emotionFreq,
    required this.prePerDay,
    required this.postPerDay,
    required this.preEmotionFreq,
    required this.postEmotionFreq,
    required this.colorAssoc,
    required this.goals,
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
  // Pre-session line / Post-session line — match analytics dashboard.
  static const _indigoPre = PdfColor.fromInt(0xFF6366F1);
  static const _greenPost = PdfColor.fromInt(0xFF10B981);
  static const _grey300 = PdfColor.fromInt(0xFFE5E7EB);
  static const _grey500 = PdfColor.fromInt(0xFF6B7280);
  static const _grey700 = PdfColor.fromInt(0xFF374151);

  // ── PDF-safe text helpers ───────────────────────────────────────────
  //
  // The default Helvetica core font shipped with the `pdf` package only
  // covers Latin-1 — em-dashes, en-dashes, emoji and other glyphs
  // render as the box/X tofu replacement char. Two-pronged fix:
  //
  //   1. Switch the document theme to NotoSans (loaded via printing's
  //      `PdfGoogleFonts.notoSansRegular`). This handles em-dashes,
  //      checkmarks, accented characters, etc.
  //   2. Strip emoji code points before drawing text — NotoSans has no
  //      emoji glyphs, so leaving them in would re-introduce tofu.
  //
  // Date / week separators are normalised to a plain ASCII hyphen
  // ("20/04/2026 - 26/04/2026") regardless of font support, per the
  // FYP demo spec.

  /// Strip emoji and other non-text symbols from [s]. Keeps Latin
  /// letters, accents, punctuation, digits, and basic symbols.
  static String safe(String s) {
    if (s.isEmpty) return s;
    final buf = StringBuffer();
    for (final r in s.runes) {
      // Keep everything below the General Punctuation block (U+2000)
      // PLUS the small set of useful glyphs in higher blocks that
      // NotoSans renders cleanly — em-dash (U+2013), en-dash (U+2014),
      // ellipsis (U+2026), checkmark (U+2713) etc.
      if (r < 0x2000) {
        buf.writeCharCode(r);
        continue;
      }
      const allow = <int>{
        0x2013, 0x2014, 0x2018, 0x2019, 0x201C, 0x201D, 0x2026, 0x2713,
      };
      if (allow.contains(r)) buf.writeCharCode(r);
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Build the PDF and hand it off to the system share / print sheet.
  static Future<void> generate(WeeklyPdfReportPayload p) async {
    // Load PDF-safe fonts once and apply them as the document theme so
    // every TextStyle inside the document inherits them — no
    // per-widget font wiring needed.
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final italic = await PdfGoogleFonts.notoSansItalic();

    final theme = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: italic,
    );

    final doc = pw.Document(
      title: 'EMOLOR Weekly Report - ${safe(p.childName)}',
      author: 'EMOLOR',
      theme: theme,
    );

    final generatedAt = _fmtDateTime(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 30),
        build: (ctx) => [
          _buildHeader(p, generatedAt),
          pw.SizedBox(height: 18),
          if (p.isEmpty) _buildEmptyState(p) else ..._buildBodySections(p),
        ],
      ),
    );

    final bytes = await doc.save();
    final safeName =
        p.childName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final filename =
        '${safeName}_EMOLOR_Report_${_fileTag(DateTime.now())}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  // ── Header ───────────────────────────────────────────────────────
  static pw.Widget _buildHeader(
      WeeklyPdfReportPayload p, String generatedAt) {
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
              _metaCol('Child', safe(p.childName)),
              _metaCol(
                  'Age', p.childAge == null ? '-' : '${p.childAge} yrs'),
              _metaCol('Week', safe(p.weekRangeLabel)),
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
            'Once ${safe(p.childName)} starts using EMOLOR during '
            '${p.weekShortLabel.toLowerCase()}, their emotional and activity '
            'data will appear here.',
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
        title: '1. Emotion Distribution',
        subtitle: 'How often each emotion was logged this week.',
        body: _emotionDistributionChart(p),
      ),
      pw.SizedBox(height: 14),
      _chartCard(
        title: '2. Emotion Trend',
        subtitle:
            'Pre-session vs Post-session emotions throughout the week.',
        body: _emotionTrendChart(p),
      ),
      pw.SizedBox(height: 14),
      _chartCard(
        title: '3. Emotion Color Association',
        subtitle: 'Which colours the child paired with each emotion.',
        body: _colorAssociationChart(p),
      ),
      pw.SizedBox(height: 14),
      _chartCard(
        title: '4. Goals Progress',
        subtitle: 'How each active goal is tracking this week.',
        body: _goalsProgressChart(p),
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
    final entries =
        p.emotionFreq.entries.where((e) => e.value > 0).toList()
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
                child: pw.Text(safe(e.key),
                    style: const pw.TextStyle(
                        fontSize: 10, color: _grey700)),
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
                width: 64,
                child: pw.Text(
                  '${e.value}x (${(pct * 100).toStringAsFixed(0)}%)',
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

  // ── Chart 2 — emotion trend (Pre vs Post per day) ────────────────
  // Twin vertical bars per day, indigo for pre-session, green for
  // post-session. Mirrors the in-app Emotion Trend line chart's
  // colour palette and Sun..Sat day order.
  static pw.Widget _emotionTrendChart(WeeklyPdfReportPayload p) {
    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final hasAny =
        p.prePerDay.any((v) => v > 0) || p.postPerDay.any((v) => v > 0);
    if (!hasAny) {
      return _emptyChartPlaceholder(
          'No pre/post-session data yet this week.');
    }
    final maxVal = [
      ...p.prePerDay,
      ...p.postPerDay
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
              return pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  bar(p.prePerDay[i], _indigoPre),
                  pw.SizedBox(width: 2),
                  bar(p.postPerDay[i], _greenPost),
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
                  style: const pw.TextStyle(
                      fontSize: 8, color: _grey500)))
              .toList(),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            _legendDot(_indigoPre, 'Pre-session'),
            pw.SizedBox(width: 16),
            _legendDot(_greenPost, 'Post-session'),
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
        decoration:
            pw.BoxDecoration(color: c, shape: pw.BoxShape.circle),
      ),
      pw.SizedBox(width: 4),
      pw.Text(label,
          style: const pw.TextStyle(fontSize: 8, color: _grey700)),
    ]);
  }

  // ── Chart 3 — emotion color association ──────────────────────────
  // One vertical bar per (emotion, hex) pair. Bar fill = the actual
  // colour the child picked, so the chart visually shows the
  // association the same way the analytics dashboard does. X-axis
  // label = emotion name.
  static pw.Widget _colorAssociationChart(WeeklyPdfReportPayload p) {
    final bars = p.colorAssoc.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    final top = bars.take(8).toList();
    if (top.isEmpty) {
      return _emptyChartPlaceholder(
          'No emotion-colour pairs yet this week.');
    }
    final maxVal = top.first.count;
    final yMax = maxVal < 2 ? 2 : (maxVal + 1);
    const chartHeight = 100.0;

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
            children: top.map((b) {
              final h = chartHeight * (b.count / yMax);
              return pw.Container(
                width: 22,
                height: h.clamp(0, chartHeight).toDouble(),
                decoration: pw.BoxDecoration(
                  color: _hexToPdf(b.hex),
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(3),
                    topRight: pw.Radius.circular(3),
                  ),
                  border: pw.Border.all(color: _grey300, width: 0.5),
                ),
              );
            }).toList(),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: top
              .map((b) => pw.SizedBox(
                    width: 50,
                    child: pw.Text(
                      safe(b.emotion),
                      textAlign: pw.TextAlign.center,
                      maxLines: 1,
                      style: const pw.TextStyle(
                          fontSize: 8, color: _grey700),
                    ),
                  ))
              .toList(),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: top
              .map((b) => pw.SizedBox(
                    width: 50,
                    child: pw.Text(
                      '${b.count}x',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontSize: 8,
                          color: _grey500,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ── Chart 4 — goals progress ─────────────────────────────────────
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
                  pw.Expanded(
                    child: pw.Text(safe(g.label),
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: _grey700),
                        maxLines: 1,
                        overflow: pw.TextOverflow.clip),
                  ),
                  pw.SizedBox(width: 6),
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
                          color:
                              pct >= 1.0 ? _greenPost : _accentPurple,
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

  // ── Summary ──────────────────────────────────────────────────────
  static pw.Widget _summarySection(WeeklyPdfReportPayload p) {
    final summary = p.aiSummary != null && p.aiSummary!.trim().isNotEmpty
        ? safe(p.aiSummary!.trim())
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
  /// has been generated yet. Stays grounded in the supplied numbers
  /// and mentions ALL FOUR chart areas:
  ///   - Emotion distribution
  ///   - Pre vs Post session change
  ///   - Emotion-colour association
  ///   - Goals progress
  static String _autoSummary(WeeklyPdfReportPayload p) {
    final name = safe(p.childName);

    // Quick existence flags so we can short-circuit cleanly.
    final emotionTotal =
        p.emotionFreq.values.fold<int>(0, (s, v) => s + v);
    final preTotal = p.prePerDay.fold<int>(0, (s, v) => s + v);
    final postTotal = p.postPerDay.fold<int>(0, (s, v) => s + v);
    final hasColours = p.colorAssoc.any((b) => b.count > 0);
    final hasGoals = p.goals.isNotEmpty;
    final hasAny = emotionTotal > 0 ||
        preTotal > 0 ||
        postTotal > 0 ||
        hasColours ||
        hasGoals;

    if (!hasAny) {
      return 'No analytics data available for this selected week. '
          'Encourage $name to log a session in EMOLOR - once they do, '
          'this report will fill in automatically.';
    }

    final parts = <String>[];

    // 1. Emotion distribution
    if (emotionTotal > 0) {
      MapEntry<String, int>? top;
      p.emotionFreq.forEach((k, v) {
        if (top == null || v > top!.value) top = MapEntry(k, v);
      });
      if (top != null) {
        parts.add(
            '$name logged $emotionTotal emotion entries this week, with "${safe(top!.key)}" being the most frequent (${top!.value} times).');
      } else {
        parts.add('$name logged $emotionTotal emotion entries this week.');
      }
    } else {
      parts.add('No in-game emotion entries were logged this week.');
    }

    // 2. Pre vs Post session change
    MapEntry<String, int>? topPre;
    MapEntry<String, int>? topPost;
    p.preEmotionFreq.forEach((k, v) {
      if (topPre == null || v > topPre!.value) topPre = MapEntry(k, v);
    });
    p.postEmotionFreq.forEach((k, v) {
      if (topPost == null || v > topPost!.value) topPost = MapEntry(k, v);
    });
    if (topPre != null && topPost != null) {
      if (topPre!.key == topPost!.key) {
        parts.add(
            'Pre-session and post-session emotions both centred on "${safe(topPre!.key)}", suggesting a steady mood across sessions.');
      } else {
        parts.add(
            'Children typically arrived feeling "${safe(topPre!.key)}" and finished feeling "${safe(topPost!.key)}" - a noticeable shift to track.');
      }
    } else if (preTotal > 0 && postTotal == 0) {
      parts.add(
          'Pre-session moods were recorded but no post-session moods yet - sessions may still be in progress.');
    } else if (preTotal == 0 && postTotal == 0) {
      parts.add('No pre/post-session emotions were captured this week.');
    }

    // 3. Emotion-colour association
    if (hasColours) {
      final sorted = [...p.colorAssoc]
        ..sort((a, b) => b.count.compareTo(a.count));
      final top = sorted.first;
      parts.add(
          'The strongest emotion-colour association was "${safe(top.emotion)}" paired with the colour ${top.hex.toUpperCase()} (${top.count} times).');
    } else {
      parts.add('No emotion-colour pairs were captured this week.');
    }

    // 4. Goals progress
    if (hasGoals) {
      final completed = p.goals
          .where((g) => g.target > 0 && g.current >= g.target)
          .length;
      if (completed == p.goals.length) {
        parts.add(
            'All ${p.goals.length} active goal${p.goals.length == 1 ? ' was' : 's were'} completed - excellent week!');
      } else if (completed > 0) {
        parts.add(
            '$completed of ${p.goals.length} active goal${p.goals.length == 1 ? ' is' : 's are'} complete; the rest are still in progress.');
      } else {
        parts.add(
            '${p.goals.length} active goal${p.goals.length == 1 ? ' is' : 's are'} still in progress.');
      }
    } else {
      parts.add('No active goals were set for this week.');
    }

    return parts.join(' ');
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

  static PdfColor _hexToPdf(String hex) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    if (v == null) return _grey300;
    return PdfColor.fromInt(v);
  }

  static String _fmtDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  static String _fileTag(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}${two(dt.month)}${two(dt.day)}_'
        '${two(dt.hour)}${two(dt.minute)}';
  }
}
