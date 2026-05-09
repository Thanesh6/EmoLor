import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
  final String weekRangeLabel;
  final String weekShortLabel;

  // ── 6 Flashcards ────────────────────────────────────────────────
  final int totalSessions;
  final String
      emotionTrendLabel; // "Positive Trend" / "Negative Trend" / "Not Enough Data"
  final int positiveSessionCount;
  final int negativeSessionCount;
  final String topPreEmotion; // "—" if none
  final int topPreCount;
  final String topPostEmotion;
  final int topPostCount;
  final String topMoodColourEmotion;
  final String topMoodColourName;
  final int topMoodColourCount;
  final String topActivityName;
  final int topActivityMinutes;

  // ── 4 Charts ────────────────────────────────────────────────────
  // Chart 1: Emotion Trend (per day, stacked pos/neg, pre + post)
  final List<int> prePositivePerDay;
  final List<int> preNegativePerDay;
  final List<int> postPositivePerDay;
  final List<int> postNegativePerDay;

  // Chart 2: Emotion Distribution (pre and post separate)
  final Map<String, int> emotionFreq; // pre-session
  final Map<String, int> postEmotionFreq; // post-session

  // Chart 3: Emotion-Colour Association (dominant per emotion)
  final List<PdfColorAssocBar> colorAssoc;

  // Chart 4: Regulation Trend (zone -2 to +3 per day)
  final List<double> preZonePerDay; // NaN if no data
  final List<double> postZonePerDay;

  /// AI summary at the end of the report.
  final String? aiSummary;

  bool get isEmpty =>
      totalSessions == 0 &&
      emotionFreq.values.every((v) => v == 0) &&
      colorAssoc.isEmpty;

  const WeeklyPdfReportPayload({
    required this.childName,
    required this.childAge,
    required this.weekRangeLabel,
    required this.weekShortLabel,
    required this.totalSessions,
    required this.emotionTrendLabel,
    required this.positiveSessionCount,
    required this.negativeSessionCount,
    required this.topPreEmotion,
    required this.topPreCount,
    required this.topPostEmotion,
    required this.topPostCount,
    required this.topMoodColourEmotion,
    required this.topMoodColourName,
    required this.topMoodColourCount,
    required this.topActivityName,
    required this.topActivityMinutes,
    required this.prePositivePerDay,
    required this.preNegativePerDay,
    required this.postPositivePerDay,
    required this.postNegativePerDay,
    required this.emotionFreq,
    required this.postEmotionFreq,
    required this.colorAssoc,
    required this.preZonePerDay,
    required this.postZonePerDay,
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
        0x2013,
        0x2014,
        0x2018,
        0x2019,
        0x201C,
        0x201D,
        0x2026,
        0x2713,
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

    debugPrint(
        'Building PDF for ${p.childName}, colorAssoc: ${p.colorAssoc.length}, emotionFreq: ${p.emotionFreq.length}');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(32, 24, 32, 24),
        maxPages: 100,
        build: (ctx) => [
          _buildHeader(p, generatedAt),
          pw.SizedBox(height: 14),
          if (p.isEmpty) _buildEmptyState(p) else ..._buildBodySections(p),
        ],
      ),
    );

    final bytes = await doc.save();
    final safeName = p.childName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final filename =
        '${safeName}_EMOLOR_Report_${_fileTag(DateTime.now())}.pdf';
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
              _metaCol('Child', safe(p.childName)),
              _metaCol('Age', p.childAge == null ? '-' : '${p.childAge} yrs'),
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
                fontSize: 11, color: _grey700, fontWeight: pw.FontWeight.bold)),
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

  // ── Body — flashcards + 4 charts + summary ───────────────────────
  static List<pw.Widget> _buildBodySections(WeeklyPdfReportPayload p) {
    return [
      _sectionTitle('Weekly Flashcards'),
      pw.SizedBox(height: 10),
      _flashcardsSection(p),
      pw.SizedBox(height: 16),
      _sectionTitle('Progress Charts'),
      pw.SizedBox(height: 10),
      _chartCard(
        title: '1. Emotion Trend',
        subtitle: 'Pre vs Post session emotions per week (Mon-Sun).',
        body: _emotionTrendChart(p),
      ),
      pw.SizedBox(height: 12),
      _chartCard(
        title: '2. Emotion Distribution',
        subtitle: 'Most frequent emotions this week (pre + post combined).',
        body: _emotionDistributionChart(p),
      ),
      pw.NewPage(),
      _chartCard(
        title: '3. Emotion Colour Association',
        subtitle: 'Dominant colour the child paired with each emotion.',
        body: _colorAssociationChart(p),
      ),
      pw.SizedBox(height: 12),
      _chartCard(
        title: '4. Regulation Trend',
        subtitle: 'Sensory zone before vs after sessions per day (-2 to +3).',
        body: _regulationTrendChart(p),
      ),
      pw.SizedBox(height: 16),
      _summarySection(p),
    ];
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: _primaryPurple,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _chartCard({
    required String title,
    required String subtitle,
    required pw.Widget body,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryPurple)),
          pw.SizedBox(height: 2),
          pw.Text(subtitle,
              style: const pw.TextStyle(fontSize: 9, color: _grey500)),
          pw.SizedBox(height: 10),
          body,
        ],
      ),
    );
  }

  // ── Flashcards ───────────────────────────────────────────────────
  static pw.Widget _flashcardsSection(WeeklyPdfReportPayload p) {
    final cards = [
      _flashcard('Total Sessions', '${p.totalSessions}',
          p.totalSessions == 0 ? 'No sessions yet' : 'this week'),
      _flashcard('Emotion Trend', p.emotionTrendLabel,
          '${p.positiveSessionCount}+ · ${p.negativeSessionCount}-'),
      _flashcard(
          'Top Pre-Emotion',
          p.topPreEmotion == '—' ? '—' : p.topPreEmotion,
          p.topPreCount > 0 ? '${p.topPreCount}x before sessions' : 'No data'),
      _flashcard(
          'Top Post-Emotion',
          p.topPostEmotion == '—' ? '—' : p.topPostEmotion,
          p.topPostCount > 0 ? '${p.topPostCount}x after sessions' : 'No data'),
      _flashcard(
          'Top Mood Colour',
          p.topMoodColourName == '—' ? '—' : p.topMoodColourName,
          p.topMoodColourCount > 0
              ? '${p.topMoodColourEmotion} · ${p.topMoodColourCount}x'
              : 'No data'),
      _flashcard(
          'Top Activity',
          p.topActivityName == '—' ? '—' : p.topActivityName,
          p.topActivityMinutes > 0 ? '${p.topActivityMinutes} min' : 'No data'),
    ];

    // Flex weights: give Emotion Trend less space, Top Activity more space
    const flexes = [1, 1, 1, 1, 1, 1];
    return pw.Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          pw.Expanded(flex: flexes[i], child: cards[i]),
          if (i < cards.length - 1) pw.SizedBox(width: 8),
        ],
      ],
    );
  }

  static pw.Widget _flashcard(String label, String value, String sub) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _bgLavender,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 8,
                  color: _grey500,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5)),
          pw.SizedBox(height: 4),
          pw.Text(safe(value),
              maxLines: 2,
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryPurple)),
          pw.SizedBox(height: 2),
          pw.Text(safe(sub),
              style: const pw.TextStyle(fontSize: 8, color: _grey500)),
        ],
      ),
    );
  }

  // ── Chart 1 — Emotion Trend ──────────────────────────────────────
  static pw.Widget _emotionTrendChart(WeeklyPdfReportPayload p) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const kDisplayToData = [1, 2, 3, 4, 5, 6, 0];

    final hasAny = p.prePositivePerDay.any((v) => v > 0) ||
        p.preNegativePerDay.any((v) => v > 0) ||
        p.postPositivePerDay.any((v) => v > 0) ||
        p.postNegativePerDay.any((v) => v > 0);

    if (!hasAny) {
      return _emptyChartPlaceholder('No pre/post session data this week.');
    }

    final allVals = [
      for (int i = 0; i < 7; i++)
        p.prePositivePerDay[i] + p.preNegativePerDay[i],
      for (int i = 0; i < 7; i++)
        p.postPositivePerDay[i] + p.postNegativePerDay[i],
    ];
    final maxVal = allVals.fold<int>(0, (m, v) => v > m ? v : m);
    final yMax = maxVal < 2 ? 2 : maxVal;
    const chartH = 80.0;
    const barW = 10.0;
    const yAxisW = 24.0;

    pw.Widget bar(int pos, int neg, PdfColor cPos, PdfColor cNeg) {
      final total = pos + neg;
      if (total == 0) {
        return pw.Container(width: barW, height: 2, color: _grey300);
      }
      final hTotal = chartH * (total / yMax);
      final hNeg = hTotal * (neg / total);
      final hPos = hTotal - hNeg;
      return pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          if (hPos > 0)
            pw.Container(
              width: barW,
              height: hPos.clamp(0, chartH).toDouble(),
              decoration: pw.BoxDecoration(
                color: cPos,
                borderRadius: const pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(2),
                  topRight: pw.Radius.circular(2),
                ),
              ),
            ),
          if (hNeg > 0)
            pw.Container(
              width: barW,
              height: hNeg.clamp(0, chartH).toDouble(),
              color: cNeg,
            ),
        ],
      );
    }

    const cPrePos = PdfColor.fromInt(0xFF6366F1);
    const cPreNeg = PdfColor.fromInt(0xFFC7D2FE);
    const cPostPos = PdfColor.fromInt(0xFF10B981);
    const cPostNeg = PdfColor.fromInt(0xFFFCA5A5);

    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            // Y axis numbers
            pw.SizedBox(
              width: yAxisW,
              height: chartH,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: List.generate(yMax + 1, (i) {
                  final val = yMax - i;
                  return pw.Text('$val',
                      style: const pw.TextStyle(fontSize: 7, color: _grey500));
                }),
              ),
            ),
            pw.SizedBox(width: 4),
            // Chart bars
            pw.Expanded(
              child: pw.Container(
                height: chartH,
                decoration: pw.BoxDecoration(
                  color: _bgSurface,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: List.generate(7, (displayIdx) {
                    final di = kDisplayToData[displayIdx];
                    return pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        bar(p.prePositivePerDay[di], p.preNegativePerDay[di],
                            cPrePos, cPreNeg),
                        pw.SizedBox(width: 2),
                        bar(p.postPositivePerDay[di], p.postNegativePerDay[di],
                            cPostPos, cPostNeg),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        // X axis labels — inline with Y axis offset
        pw.Row(
          children: [
            pw.SizedBox(width: yAxisW + 4),
            pw.Expanded(
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: labels
                    .map((l) => pw.SizedBox(
                          width: 28,
                          child: pw.Text(l,
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(
                                  fontSize: 7, color: _grey500)),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            _legendDot(cPrePos, 'Pre · Pos'),
            pw.SizedBox(width: 10),
            _legendDot(cPreNeg, 'Pre · Neg'),
            pw.SizedBox(width: 10),
            _legendDot(cPostPos, 'Post · Pos'),
            pw.SizedBox(width: 10),
            _legendDot(cPostNeg, 'Post · Neg'),
          ],
        ),
      ],
    );
  }

  // ── Chart 2 — Emotion Distribution ──────────────────────────────
  static pw.Widget _emotionDistributionChart(WeeklyPdfReportPayload p) {
    final hasAny = p.emotionFreq.values.any((v) => v > 0) ||
        p.postEmotionFreq.values.any((v) => v > 0);
    if (!hasAny) {
      return _emptyChartPlaceholder('No emotion entries this week.');
    }
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _distributionPanel(
            'Positive',
            p.emotionFreq,
            const PdfColor.fromInt(0xFF10B981),
            const PdfColor.fromInt(0xFFE6F7EE),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _distributionPanel(
            'Negative',
            p.postEmotionFreq,
            const PdfColor.fromInt(0xFFEF4444),
            const PdfColor.fromInt(0xFFFEE2E2),
          ),
        ),
      ],
    );
  }

  static pw.Widget _distributionPanel(
    String title,
    Map<String, int> freq,
    PdfColor accentColor,
    PdfColor bgColor,
  ) {
    final entries = freq.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();
    final total = top.fold<int>(0, (s, e) => s + e.value);

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: accentColor,
            ),
          ),
          pw.Text(
            total > 0 ? '$total times' : '0 times',
            style: const pw.TextStyle(fontSize: 8, color: _grey500),
          ),
          pw.SizedBox(height: 8),
          if (top.isEmpty)
            pw.Text('No data',
                style: const pw.TextStyle(fontSize: 8, color: _grey500))
          else
            ...top.map((e) {
              final pct = total > 0 ? e.value / total : 0.0;
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 50,
                      child: pw.Text(safe(e.key),
                          style:
                              const pw.TextStyle(fontSize: 8, color: _grey700)),
                    ),
                    pw.Expanded(
                      child: pw.Stack(
                        children: [
                          pw.Container(
                            height: 8,
                            decoration: pw.BoxDecoration(
                              color: _grey300,
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                          ),
                          pw.LayoutBuilder(builder: (ctx, constraints) {
                            final w = (constraints?.maxWidth ?? 100) *
                                pct.clamp(0.02, 1.0);
                            return pw.Container(
                              width: w,
                              height: 8,
                              decoration: pw.BoxDecoration(
                                color: accentColor,
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 4),
                    pw.SizedBox(
                      width: 38,
                      child: pw.Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 7,
                            color: _grey700,
                            fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  // ── Chart 3 — Emotion Colour Association ────────────────────────
  static pw.Widget _colorAssociationChart(WeeklyPdfReportPayload p) {
    if (p.colorAssoc.isEmpty) {
      return _emptyChartPlaceholder('No emotion-colour pairs this week.');
    }
    final maxVal =
        p.colorAssoc.map((b) => b.count).fold<int>(0, (m, v) => v > m ? v : m);
    final yMax = maxVal < 2 ? 2 : (maxVal + 1);
    const chartH = 75.0;

    return pw.Column(
      children: [
        pw.Container(
          height: chartH,
          decoration: pw.BoxDecoration(
            color: _bgSurface,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: p.colorAssoc.map((b) {
              final h = chartH * (b.count / yMax);
              return pw.Container(
                width: 24,
                height: h.clamp(2, chartH).toDouble(),
                decoration: pw.BoxDecoration(
                  color: _hexToPdf(b.hex),
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(4),
                    topRight: pw.Radius.circular(4),
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
          children: p.colorAssoc
              .map((b) => pw.SizedBox(
                    width: 40,
                    child: pw.Column(children: [
                      pw.Text(safe(b.emotion),
                          textAlign: pw.TextAlign.center,
                          style:
                              const pw.TextStyle(fontSize: 7, color: _grey700)),
                      pw.Text(safe(_hexToColorName(b.hex)),
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                              fontSize: 6,
                              color: _hexToPdf(b.hex),
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text('${b.count}x',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                              fontSize: 6,
                              color: _grey500,
                              fontWeight: pw.FontWeight.bold)),
                    ]),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ── Chart 4 — Regulation Trend ───────────────────────────────────
  static pw.Widget _regulationTrendChart(WeeklyPdfReportPayload p) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const kDisplayToData = [1, 2, 3, 4, 5, 6, 0];
    const yLabels = ['+3', '+2', '+1', '0', '-1', '-2'];
    const yValues = [3.0, 2.0, 1.0, 0.0, -1.0, -2.0];

    final hasData = p.preZonePerDay.any((v) => !v.isNaN) ||
        p.postZonePerDay.any((v) => !v.isNaN);
    if (!hasData) {
      return _emptyChartPlaceholder(
          'No zone data yet. Complete pre & post check-ins.');
    }

    const chartH = 90.0;
    const minZone = -2.0;
    const maxZone = 3.0;
    const zoneRange = maxZone - minZone;
    const yAxisW = 24.0;
    const dotSize = 7.0;

    // Convert zone value to Y position (top=0, bottom=chartH)
    double zoneToY(double zone) => chartH * (1 - (zone - minZone) / zoneRange);

    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Y axis labels
            pw.SizedBox(
              width: yAxisW,
              height: chartH,
              child: pw.Stack(
                children: List.generate(yValues.length, (i) {
                  final y = zoneToY(yValues[i]);
                  return pw.Positioned(
                    top: (y - 5).clamp(0, chartH - 10).toDouble(),
                    right: 2,
                    child: pw.Text(yLabels[i],
                        style:
                            const pw.TextStyle(fontSize: 7, color: _grey500)),
                  );
                }),
              ),
            ),
            pw.SizedBox(width: 4),
            // Chart area
            pw.Expanded(
              child: pw.Stack(
                children: [
                  // Background + grid lines
                  pw.Container(
                    height: chartH,
                    decoration: pw.BoxDecoration(
                      color: _bgSurface,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                  ),
                  // Horizontal grid lines at each zone level
                  ...List.generate(yValues.length, (i) {
                    final y = zoneToY(yValues[i]);
                    return pw.Positioned(
                      top: y.clamp(0, chartH - 1).toDouble(),
                      left: 0,
                      right: 0,
                      child: pw.Container(
                        height: 0.5,
                        color: _grey300,
                      ),
                    );
                  }),
                  // Dots per day
                  pw.SizedBox(
                    height: chartH,
                    child: pw.LayoutBuilder(
                      builder: (ctx, constraints) {
                        final totalW = constraints?.maxWidth ?? 400;
                        final colW = totalW / 7;
                        final dots = <pw.Widget>[];
                        for (int displayIdx = 0; displayIdx < 7; displayIdx++) {
                          final di = kDisplayToData[displayIdx];
                          final cx = colW * displayIdx + colW / 2;
                          if (!p.preZonePerDay[di].isNaN) {
                            dots.add(pw.Positioned(
                              left: (cx - dotSize / 2)
                                  .clamp(0, totalW - dotSize)
                                  .toDouble(),
                              top: (zoneToY(p.preZonePerDay[di]) - dotSize / 2)
                                  .clamp(0, chartH - dotSize)
                                  .toDouble(),
                              child: pw.Container(
                                width: dotSize,
                                height: dotSize,
                                decoration: pw.BoxDecoration(
                                  color: _indigoPre,
                                  shape: pw.BoxShape.circle,
                                ),
                              ),
                            ));
                          }
                          if (!p.postZonePerDay[di].isNaN) {
                            dots.add(pw.Positioned(
                              left: (cx - dotSize / 2 + 4)
                                  .clamp(0, totalW - dotSize)
                                  .toDouble(),
                              top: (zoneToY(p.postZonePerDay[di]) - dotSize / 2)
                                  .clamp(0, chartH - dotSize)
                                  .toDouble(),
                              child: pw.Container(
                                width: dotSize,
                                height: dotSize,
                                decoration: pw.BoxDecoration(
                                  color: _greenPost,
                                  shape: pw.BoxShape.circle,
                                ),
                              ),
                            ));
                          }
                        }
                        return pw.Stack(children: dots);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        // X axis labels aligned with chart area
        pw.Row(
          children: [
            pw.SizedBox(width: yAxisW + 4),
            pw.Expanded(
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: labels
                    .map((l) => pw.Text(l,
                        style:
                            const pw.TextStyle(fontSize: 8, color: _grey500)))
                    .toList(),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            _legendDot(_indigoPre, 'Pre-session zone'),
            pw.SizedBox(width: 16),
            _legendDot(_greenPost, 'Post-session zone'),
            pw.SizedBox(width: 16),
            pw.Text('+3=Overload  0=Balanced  -2=Withdrawal',
                style: const pw.TextStyle(fontSize: 7, color: _grey500)),
          ],
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
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _bgLavender,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _accentPurple, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          ...summary.split('\n').map((line) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) return pw.SizedBox(height: 10);
            final isTitle = trimmed.startsWith('EMOLOR');
            final isDate = RegExp(r'^\d{2}/\d{2}/\d{4}').hasMatch(trimmed);
            final isCaregiverNote = trimmed.startsWith('Caregiver Note:');
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                trimmed,
                style: pw.TextStyle(
                  fontSize: isTitle
                      ? 13
                      : isDate
                          ? 9
                          : isCaregiverNote
                              ? 11
                              : 10,
                  fontWeight: isTitle || isCaregiverNote
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  color: isTitle || isCaregiverNote
                      ? _primaryPurple
                      : isDate
                          ? _grey500
                          : _grey700,
                  lineSpacing: 1.4,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  static String _autoSummary(WeeklyPdfReportPayload p) {
    final name = safe(p.childName);
    if (p.isEmpty) {
      return 'No data available for this week. Encourage $name to '
          'complete sessions in EMOLOR to generate a full report.';
    }
    final parts = <String>[];
    parts.add(
        '$name completed ${p.totalSessions} session${p.totalSessions == 1 ? '' : 's'} '
        'this week with an overall ${p.emotionTrendLabel.toLowerCase()}.');
    if (p.topPreEmotion != '—' && p.topPostEmotion != '—') {
      parts.add(
          'Before sessions, ${p.topPreEmotion.toLowerCase()} was most common; '
          'after sessions, ${p.topPostEmotion.toLowerCase()} appeared most frequently.');
    }
    if (p.topMoodColourCount > 0) {
      parts.add('${p.topMoodColourEmotion} was most often paired with '
          '${p.topMoodColourName} this week.');
    }
    if (p.topActivityMinutes > 0) {
      parts.add('The most engaged activity was ${p.topActivityName} '
          '(${p.topActivityMinutes} min).');
    }
    return parts.join(' ');
  }

  static pw.Widget _legendDot(PdfColor c, String label) {
    return pw.Row(children: [
      pw.Container(
          width: 7,
          height: 7,
          decoration: pw.BoxDecoration(color: c, shape: pw.BoxShape.circle)),
      pw.SizedBox(width: 3),
      pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _grey700)),
    ]);
  }

  static pw.Widget _emptyChartPlaceholder(String msg) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 12),
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: _bgSurface,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _grey300),
      ),
      child:
          pw.Text(msg, style: const pw.TextStyle(fontSize: 9, color: _grey500)),
    );
  }

  static PdfColor _emotionColor(String name) {
    switch (name) {
      case 'Happy':
        return const PdfColor.fromInt(0xFFFBBF24);
      case 'Sad':
        return const PdfColor.fromInt(0xFF60A5FA);
      case 'Angry':
        return const PdfColor.fromInt(0xFFEF4444);
      case 'Calm':
        return const PdfColor.fromInt(0xFF14B8A6);
      case 'Excited':
        return const PdfColor.fromInt(0xFFF97316);
      case 'Scared':
        return const PdfColor.fromInt(0xFF9B5DE5);
      case 'Loved':
        return const PdfColor.fromInt(0xFFEC4899);
      case 'Tired':
        return const PdfColor.fromInt(0xFF94A3B8);
      default:
        return _accentPurple;
    }
  }

  static String _hexToColorName(String hex) {
    const map = {
      '#E57373': 'Red',
      '#FF8A65': 'Orange',
      '#FFD54F': 'Yellow',
      '#F06292': 'Pink',
      '#81C784': 'Green',
      '#A1887F': 'Brown',
      '#64B5F6': 'Blue',
      '#9575CD': 'Purple',
      '#90A4AE': 'Grey',
    };
    return map[hex] ?? hex;
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
