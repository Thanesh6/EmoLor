import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:math';

class PdfReportService {
  static Future<void> generateReport({
    required String childName,
    required String summaryInsight,
    required Map<String, int> emotionFreq,
    required Map<String, double> gameAvgStars,
  }) async {
    final pdf = pw.Document();

    // Calculate top emotion and total
    final totalEmotions = max(1, emotionFreq.values.fold(0, (s, v) => s + v));
    final sortedEmotions = emotionFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Prepare table data for games
    final gameTableData = [
      ['Game', 'Avg Score (0-3)'],
      ...gameAvgStars.entries.map((e) => [e.key.replaceAll('EMO', ''), e.value.toStringAsFixed(1)])
    ];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 20),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 2)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("EmoLor Progress Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.purple800)),
                        pw.SizedBox(height: 5),
                        pw.Text("Child: $childName", style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Text("Date: ${DateTime.now().toString().split(' ')[0]}", style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Insights Summary
              pw.Text("Insights Summary", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.purple600)),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.purple50,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(summaryInsight, style: const pw.TextStyle(fontSize: 14, color: PdfColors.black, lineSpacing: 1.5)),
              ),
              pw.SizedBox(height: 30),

              // Emotion Distribution
              pw.Text("Emotion Distribution", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.purple600)),
              pw.SizedBox(height: 12),
              pw.Column(
                children: sortedEmotions.map((e) {
                  final pct = (e.value / totalEmotions);
                  final pctString = (pct * 100).toStringAsFixed(0);
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Row(
                      children: [
                        pw.SizedBox(width: 80, child: pw.Text(e.key, style: const pw.TextStyle(fontSize: 12))),
                        pw.Expanded(
                          child: pw.Stack(
                            children: [
                              pw.Container(
                                height: 16,
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.grey200,
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                              ),
                              pw.Container(
                                height: 16,
                                width: 300 * pct, // approximate visual scale
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.purple400,
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 40, child: pw.Text("  $pctString%", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                  );
                }).toList(),
              ),
              pw.SizedBox(height: 30),

              // Activity Performance Table
              pw.Text("Activity Performance", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.purple600)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                data: gameTableData,
                border: pw.TableBorder.all(color: PdfColors.grey200),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.purple800),
                cellHeight: 25,
                cellStyle: const pw.TextStyle(fontSize: 11),
                headerPadding: const pw.EdgeInsets.all(8),
                cellPadding: const pw.EdgeInsets.all(8),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                },
              ),
            ],
          );
        },
      ),
    );

    // Prompt user to print/save
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: "${childName}_Progress_Report.pdf",
    );
  }
}
