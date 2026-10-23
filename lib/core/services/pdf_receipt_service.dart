import 'dart:typed_data';
import 'package:intl/intl.dart';
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
    this.receiptNotice,
    this.changeGiven,
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
  final String? receiptNotice;
  final int? changeGiven;

  bool get isCredit => creditAmount > 0;
}

/// Service responsable de la construction du document PDF de reçu (Thermique 80mm ou Facture A4).
class PdfReceiptService {
  /// Génère les octets du fichier PDF (format Thermique 80mm ou Facture A4).
  static Future<Uint8List> generateReceiptPdf(ReceiptData data, {bool isThermal = false}) async {
    if (isThermal) {
      return generateThermalReceiptPdf(data);
    }
    return generateInvoiceA4Pdf(data);
  }

  /// Génère un ticket au format rouleau thermique 80mm (prêt pour imprimante de caisse type Xprinter/Epson).
  static Future<Uint8List> generateThermalReceiptPdf(ReceiptData data) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    const navyColor = PdfColor.fromInt(0xFF0F1B3D);
    const redColor = PdfColor.fromInt(0xFFEF4444);
    const emeraldColor = PdfColor.fromInt(0xFF10B981);

    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── En-tête Boutique ──
              pw.Center(
                child: pw.Text(
                  data.businessName.toUpperCase(),
                  style: pw.TextStyle(font: fontBold, fontSize: 13, color: navyColor),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              if (data.businessAddress.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    data.businessAddress,
                    style: pw.TextStyle(font: font, fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
              if (data.businessPhone.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    'Tél : ${data.businessPhone}',
                    style: pw.TextStyle(font: font, fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
              if (data.businessNif.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    'NIF : ${data.businessNif}',
                    style: pw.TextStyle(font: font, fontSize: 7),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // ── Référence Ticket & Date ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TICKET: ${data.reference}', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                  pw.Text(dateFmt.format(data.date), style: pw.TextStyle(font: font, fontSize: 7.5)),
                ],
              ),
              if (data.customerName != null && data.customerName!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text('Client : ${data.customerName!.trim()}', style: pw.TextStyle(font: font, fontSize: 8)),
              ],

              pw.SizedBox(height: 5),
              pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // ── Entête colonnes ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('DÉSIGNATION', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                  pw.Text('TOTAL', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 3),

              // ── Articles ──
              ...data.lines.map((line) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Text(line.name, style: pw.TextStyle(font: fontBold, fontSize: 8)),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${line.quantity} ${line.unit} x ${formatGnf(line.unitPrice)}',
                            style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey700),
                          ),
                          pw.Text(formatGnf(line.lineTotal), style: pw.TextStyle(font: fontBold, fontSize: 8)),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // ── Totaux ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL À PAYER', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  pw.Text(formatGnf(data.total), style: pw.TextStyle(font: fontBold, fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Règlement :', style: pw.TextStyle(font: font, fontSize: 8)),
                  pw.Text(data.paymentMethodLabel, style: pw.TextStyle(font: fontBold, fontSize: 8)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Montant Reçu :', style: pw.TextStyle(font: font, fontSize: 8)),
                  pw.Text(formatGnf(data.amountPaid), style: pw.TextStyle(font: fontBold, fontSize: 8)),
                ],
              ),
              if (data.changeGiven != null && data.changeGiven! > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Monnaie Rendue :', style: pw.TextStyle(font: fontBold, fontSize: 8, color: emeraldColor)),
                    pw.Text(formatGnf(data.changeGiven!), style: pw.TextStyle(font: fontBold, fontSize: 8, color: emeraldColor)),
                  ],
                ),
              ],
              if (data.isCredit) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('RESTE DÛ (CRÉDIT) :', style: pw.TextStyle(font: fontBold, fontSize: 8, color: redColor)),
                    pw.Text(formatGnf(data.creditAmount), style: pw.TextStyle(font: fontBold, fontSize: 9, color: redColor)),
                  ],
                ),
              ],

              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 6),

              // ── Pied de Ticket ──
              if (data.receiptNotice != null && data.receiptNotice!.trim().isNotEmpty) ...[
                pw.Center(
                  child: pw.Text(
                    data.receiptNotice!.trim(),
                    style: pw.TextStyle(font: font, fontSize: 7, fontStyle: pw.FontStyle.italic),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 4),
              ],
              pw.Center(
                child: pw.Text(
                  'Merci pour votre confiance !',
                  style: pw.TextStyle(font: fontBold, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(
                  'N\'MaShop POS • Ventes & Caisse',
                  style: pw.TextStyle(font: font, fontSize: 6.5, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Génère une facture complète au format A4 standard avec mentions légales et signatures.
  static Future<Uint8List> generateInvoiceA4Pdf(ReceiptData data) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    // Couleurs officielles de marque N'MaShop & Boutique
    const navyColor = PdfColor.fromInt(0xFF0F1B3D);
    const orangeColor = PdfColor.fromInt(0xFFE85D04);
    const emeraldColor = PdfColor.fromInt(0xFF10B981);
    const redColor = PdfColor.fromInt(0xFFEF4444);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return [
            // ── En-Tête Graphique Boutique & N'MaShop ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        // Badge Emblem Boutique
                        pw.Container(
                          width: 32,
                          height: 32,
                          decoration: pw.BoxDecoration(
                            color: orangeColor,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              data.businessName.isNotEmpty ? data.businessName[0].toUpperCase() : 'N',
                              style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.white),
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Text(
                          data.businessName.toUpperCase(),
                          style: pw.TextStyle(font: fontBold, fontSize: 20, color: navyColor),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    if (data.businessAddress.isNotEmpty)
                      pw.Text(data.businessAddress, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey800)),
                    if (data.businessPhone.isNotEmpty)
                      pw.Text('Tél : ${data.businessPhone}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey800)),
                    if (data.businessNif.isNotEmpty)
                      pw.Text('NIF / RCCM : ${data.businessNif}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey800)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // Badge de Statut
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: data.isCredit ? redColor : emeraldColor,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        data.isCredit ? 'À CRÉDIT' : 'FACTURE PAYÉE',
                        style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('N° Réf : ${data.reference}', style: pw.TextStyle(font: fontBold, fontSize: 11, color: navyColor)),
                    pw.Text('Date : ${formatDateTime(data.date)}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 16),
            // Ligne de séparation aux couleurs de la marque
            pw.Container(height: 3, color: orangeColor),
            pw.SizedBox(height: 16),

            // ── Informations Client ──
            if (data.customerName != null && data.customerName!.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF8FAFC),
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('CLIENT / DESTINATAIRE :', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey600)),
                        pw.SizedBox(height: 2),
                        pw.Text(data.customerName!, style: pw.TextStyle(font: fontBold, fontSize: 12, color: navyColor)),
                      ],
                    ),
                    pw.Text('Mode : ${data.paymentMethodLabel}', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey800)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
            ],

            // ── Tableau des Articles ──
            pw.TableHelper.fromTextArray(
              headers: ['Désignation', 'Prix Unitaire', 'Quantité', 'Total'],
              data: [
                for (final line in data.lines)
                  [
                    line.name,
                    '${formatAmount(line.unitPrice)} / ${line.unit}',
                    '${line.quantity}',
                    formatAmount(line.lineTotal),
                  ]
              ],
              border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: navyColor),
              cellStyle: pw.TextStyle(font: font, fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
              },
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            pw.SizedBox(height: 16),

            // ── Totaux & Règlement ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 260,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFF1F5F9),
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColor.fromInt(0xFFCBD5E1)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('MONTANT TOTAL', style: pw.TextStyle(font: fontBold, fontSize: 12, color: navyColor)),
                          pw.Text(formatGnf(data.total), style: pw.TextStyle(font: fontBold, fontSize: 13, color: navyColor)),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Montant Encaissé', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                          pw.Text(formatGnf(data.amountPaid), style: pw.TextStyle(font: fontBold, fontSize: 10, color: emeraldColor)),
                        ],
                      ),
                      if (data.isCredit) ...[
                        pw.SizedBox(height: 6),
                        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('RESTE À PAYER', style: pw.TextStyle(font: fontBold, fontSize: 11, color: redColor)),
                            pw.Text(formatGnf(data.creditAmount), style: pw.TextStyle(font: fontBold, fontSize: 11, color: redColor)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 32),

            // ── Cachet & Signature ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Signature du Client :', style: pw.TextStyle(font: fontBold, fontSize: 9, color: navyColor)),
                    pw.SizedBox(height: 30),
                    pw.Container(width: 150, height: 0.5, color: PdfColors.grey400),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Cachet & Signature Boutique :', style: pw.TextStyle(font: fontBold, fontSize: 9, color: navyColor)),
                    pw.SizedBox(height: 30),
                    pw.Container(width: 150, height: 0.5, color: PdfColors.grey400),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // ── Footer de Double Marque (Boutique Client + N'MaShop) ──
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF8FAFC),
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  if (data.receiptNotice != null && data.receiptNotice!.trim().isNotEmpty) ...[
                    pw.Text(
                      data.receiptNotice!.trim(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 7.5,
                        color: navyColor,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                  ],
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Merci de votre confiance ! À bientôt chez ${data.businessName}.',
                        style: pw.TextStyle(font: font, fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Généré avec N\'MaShop Desktop',
                        style: pw.TextStyle(font: fontBold, fontSize: 8, color: orangeColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }
}
