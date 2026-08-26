import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../format/formatters.dart';

/// Données d'une ligne d'article pour l'impression du reçu.
class ReceiptLineItem {
  const ReceiptLineItem({
    required this.name,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String name;
  final String unit;
  final int quantity;
  final int unitPrice;
  final int lineTotal;
}

/// Données complètes d'un reçu de vente.
class ReceiptData {
  const ReceiptData({
    required this.reference,
    required this.date,
    required this.businessName,
    required this.businessPhone,
    required this.businessAddress,
    required this.businessNif,
    required this.lines,
    required this.total,
    required this.amountPaid,
    required this.creditAmount,
    required this.paymentMethodLabel,
    this.customerName,
  });

  final String reference;
  final DateTime date;
  final String businessName;
  final String businessPhone;
  final String businessAddress;
  final String businessNif;
  final List<ReceiptLineItem> lines;
  final int total;
  final int amountPaid;
  final int creditAmount;
  final String paymentMethodLabel;
  final String? customerName;

  bool get isCredit => creditAmount > 0;
}

/// Service responsable de la construction du document PDF de reçu.
class PdfReceiptService {
  /// Génère les octets du fichier PDF pour un [ReceiptData] donné.
  static Future<Uint8List> generateReceiptPdf(ReceiptData data) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header: Business Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      data.businessName.toUpperCase(),
                      style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.indigo800),
                    ),
                    pw.SizedBox(height: 4),
                    if (data.businessAddress.isNotEmpty)
                      pw.Text(data.businessAddress, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                    if (data.businessPhone.isNotEmpty)
                      pw.Text('Tél : ${data.businessPhone}', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                    if (data.businessNif.isNotEmpty)
                      pw.Text('NIF : ${data.businessNif}', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('FACTURE', style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.grey400)),
                    pw.SizedBox(height: 4),
                    pw.Text('Réf : ${data.reference}', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                    pw.Text('Date : ${formatDateTime(data.date)}', style: pw.TextStyle(font: font, fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 24),

            // Customer Info
            if (data.customerName != null && data.customerName!.isNotEmpty) ...[
              pw.Text('FACTURE À :', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey600)),
              pw.SizedBox(height: 4),
              pw.Text(data.customerName!, style: pw.TextStyle(font: fontBold, fontSize: 14)),
              pw.SizedBox(height: 24),
            ],

            // Table of items
            pw.TableHelper.fromTextArray(
              headers: ['Désignation', 'PU', 'Quantité', 'Total'],
              data: [
                for (final line in data.lines)
                  [
                    line.name,
                    '${formatAmount(line.unitPrice)} / ${line.unit}',
                    '${line.quantity}',
                    formatAmount(line.lineTotal),
                  ]
              ],
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo600),
              cellStyle: pw.TextStyle(font: font, fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
              },
              cellPadding: const pw.EdgeInsets.all(8),
            ),
            pw.SizedBox(height: 24),

            // Totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 250,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('TOTAL', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                          pw.Text(formatGnf(data.total), style: pw.TextStyle(font: fontBold, fontSize: 14)),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Paiement (${data.paymentMethodLabel})', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                          pw.Text(formatGnf(data.amountPaid), style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                      if (data.isCredit) ...[
                        pw.SizedBox(height: 8),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('RESTE DÛ', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.red600)),
                            pw.Text(formatGnf(data.creditAmount), style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.red600)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 48),

            // Footer
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Signature Client', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                pw.Text('Cachet & Signature', style: pw.TextStyle(font: fontBold, fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 60),
            pw.Center(
              child: pw.Text('Merci de votre confiance.', style: pw.TextStyle(font: font, fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }
}
