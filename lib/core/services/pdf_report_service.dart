import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../format/formatters.dart';
import '../../features/reports/application/reports_providers.dart';

/// Service responsable de la génération du Rapport Financier en format PDF
class PdfReportService {
  static Future<Uint8List> generateReportPdf({
    required ReportData data,
    required ReportRange range,
    required String businessName,
    required String businessPhone,
    required String businessAddress,
    required String businessNif,
  }) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    const navyColor = PdfColor.fromInt(0xFF0F1B3D);
    const orangeColor = PdfColor.fromInt(0xFFE85D04);
    const emeraldColor = PdfColor.fromInt(0xFF10B981);
    const redColor = PdfColor.fromInt(0xFFEF4444);

    final dayFmt = DateFormat('dd/MM/yyyy HH:mm', 'fr');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return [
            // ── En-Tête Rapport Boutique & N'MaShop ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      businessName.toUpperCase(),
                      style: pw.TextStyle(font: fontBold, fontSize: 18, color: navyColor),
                    ),
                    pw.SizedBox(height: 4),
                    if (businessAddress.isNotEmpty)
                      pw.Text(businessAddress, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey800)),
                    if (businessPhone.isNotEmpty)
                      pw.Text('Tél : $businessPhone', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey800)),
                    if (businessNif.isNotEmpty)
                      pw.Text('NIF : $businessNif', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey800)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: navyColor,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'RAPPORT FINANCIER',
                        style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('Période : ${range.label}', style: pw.TextStyle(font: fontBold, fontSize: 10, color: orangeColor)),
                    pw.Text('Généré le : ${dayFmt.format(DateTime.now())}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 12),
            pw.Container(height: 2.5, color: orangeColor),
            pw.SizedBox(height: 16),

            // ── KPISynthétiques ──
            pw.Text('INDICATEURS CLÉS DE PERFORMANCE', style: pw.TextStyle(font: fontBold, fontSize: 11, color: navyColor)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Métrique', 'Valeur', 'Détails / Volume'],
              data: [
                ['Chiffre d\'Affaires (CA)', formatGnf(data.revenue), '${data.salesCount} ventes effectuées'],
                ['Bénéfice Brut (Marge)', formatGnf(data.grossProfit), 'Marge brute sur les ventes'],
                ['Total Dépenses', formatGnf(data.totalExpenses), '${data.expensesByCategory.length} catégories'],
                ['Bénéfice Net', formatGnf(data.netProfit), data.netProfit >= 0 ? 'Rentable' : 'Déficitaire'],
              ],
              border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: navyColor),
              cellStyle: pw.TextStyle(font: font, fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerLeft,
              },
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),

            pw.SizedBox(height: 20),

            // ── Top Produits ──
            if (data.topProducts.isNotEmpty) ...[
              pw.Text('TOP PRODUITS VENDUS', style: pw.TextStyle(font: fontBold, fontSize: 11, color: navyColor)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['N°', 'Nom du Produit', 'Quantité Vendue', 'Chiffre d\'Affaires Généré'],
                data: [
                  for (int i = 0; i < data.topProducts.length; i++)
                    [
                      '${i + 1}',
                      data.topProducts[i].name,
                      '${data.topProducts[i].quantitySold} unités',
                      formatGnf(data.topProducts[i].revenue),
                    ]
                ],
                border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
                headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF334155)),
                cellStyle: pw.TextStyle(font: font, fontSize: 9),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                },
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              pw.SizedBox(height: 20),
            ],

            // ── Bilan Financier Détaillé ──
            pw.Text('RÉSUMÉ FINANCIER & TRÉSORERIE', style: pw.TextStyle(font: fontBold, fontSize: 11, color: navyColor)),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF8FAFC),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFCBD5E1)),
              ),
              child: pw.Column(
                children: [
                  _pdfSummaryRow('Chiffre d\'Affaires Total', formatGnf(data.revenue), fontBold, navyColor),
                  _pdfSummaryRow('Montant Encaissé (Comptant/Mobile)', formatGnf(data.collected), font, emeraldColor),
                  _pdfSummaryRow('Créances Client (Restes dûs)', formatGnf(data.receivables), font, orangeColor),
                  pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                  _pdfSummaryRow('Bénéfice Brut', formatGnf(data.grossProfit), font, emeraldColor),
                  _pdfSummaryRow('Total Dépenses', '- ${formatGnf(data.totalExpenses)}', font, redColor),
                  pw.Divider(color: PdfColors.grey400, thickness: 1),
                  _pdfSummaryRow('BÉNÉFICE NET FINAL', formatGnf(data.netProfit), fontBold, data.netProfit >= 0 ? emeraldColor : redColor, isTitle: true),
                ],
              ),
            ),

            pw.SizedBox(height: 30),

            // ── Signatures & Validation ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Établi par (Gérant / Admin) :', style: pw.TextStyle(font: fontBold, fontSize: 9, color: navyColor)),
                    pw.SizedBox(height: 24),
                    pw.Container(width: 150, height: 0.5, color: PdfColors.grey400),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Visa & Cachet Direction :', style: pw.TextStyle(font: fontBold, fontSize: 9, color: navyColor)),
                    pw.SizedBox(height: 24),
                    pw.Container(width: 150, height: 0.5, color: PdfColors.grey400),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 30),

            // ── Footer Double Marque ──
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF1F5F9),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Rapport Officiel — $businessName', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                  pw.Text('Généré avec N\'MaShop Desktop v2.0', style: pw.TextStyle(font: fontBold, fontSize: 8, color: orangeColor)),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _pdfSummaryRow(String label, String value, pw.Font font, PdfColor color, {bool isTitle = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: isTitle ? 11 : 9, color: isTitle ? PdfColors.black : PdfColors.grey800)),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: isTitle ? 12 : 9, color: color)),
        ],
      ),
    );
  }
}
