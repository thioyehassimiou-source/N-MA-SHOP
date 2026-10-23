import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/caisse/domain/z_report_data.dart';
import '../format/formatters.dart';

/// Service de génération des documents PDF pour la Clôture de Caisse (Rapport Z).
/// Prend en charge le Format Ticket Thermique 80mm et le Format Officiel A4.
class PdfZReportService {
  /// ─── 1. FORMAT TICKET THERMIQUE 80MM ──────────────────────────────────────
  static Future<Uint8List> generateThermalZReportPdf(ZReportData data) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final dateFmt = DateFormat('dd/MM/yyyy', 'fr');
    final timeFmt = DateFormat('HH:mm', 'fr');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── En-tête Boutique ──
              pw.Center(
                child: pw.Text(
                  data.businessName.toUpperCase(),
                  style: pw.TextStyle(font: fontBold, fontSize: 13),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              if (data.businessAddress.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    data.businessAddress,
                    style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey800),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
              if (data.businessPhone.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Center(
                  child: pw.Text(
                    'Tél : ${data.businessPhone}',
                    style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey800),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
              if (data.businessNif.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Center(
                  child: pw.Text(
                    'NIF : ${data.businessNif}',
                    style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey800),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // ── Titre Document ──
              pw.Center(
                child: pw.Text(
                  'CLÔTURE DE CAISSE (RAPPORT Z)',
                  style: pw.TextStyle(font: fontBold, fontSize: 9.5),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date : ${dateFmt.format(data.date)}', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                  pw.Text('Heure : ${timeFmt.format(data.generatedAt)}', style: pw.TextStyle(font: font, fontSize: 8)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Caissier / Opérateur :', style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey700)),
                  pw.Text(data.cashierName, style: pw.TextStyle(font: fontBold, fontSize: 8)),
                ],
              ),

              pw.SizedBox(height: 5),
              pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // ── 1. Ventes & Chiffre d'Affaires ──
              pw.Text('1. ACTIVITÉ COMMERCIALE', style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
              pw.SizedBox(height: 3),
              _thermalRow('Nombre de Ventes :', '${data.totalSalesCount}', font, fontBold),
              _thermalRow('Chiffre d\'Affaires Brut :', formatGnf(data.totalRevenue), font, fontBold),
              if (data.totalSalesCount > 0)
                _thermalRow('Panier Moyen :', formatGnf(data.averageBasket), font, font),

              pw.SizedBox(height: 5),
              pw.Divider(thickness: 0.6, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 3),

              // ── 2. Ventilation des Règlements ──
              pw.Text('2. VENTILATION PAR RÈGLEMENT', style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
              pw.SizedBox(height: 3),
              _thermalRow('• Espèces (Cash) :', formatGnf(data.cashSales), font, fontBold),
              _thermalRow('• Mobile Money (OM/MoMo) :', formatGnf(data.mobileMoneySales), font, fontBold),
              _thermalRow('• Virement / Chèque :', formatGnf(data.bankSales), font, fontBold),
              if (data.creditSales > 0)
                _thermalRow('• Ventes à Crédit (Restes dûs) :', formatGnf(data.creditSales), font, fontBold),

              if (data.totalCreditPayments > 0) ...[
                pw.SizedBox(height: 5),
                pw.Divider(thickness: 0.6, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 3),
                pw.Text('3. RECOUVREMENTS CRÉANCES', style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
                pw.SizedBox(height: 3),
                _thermalRow('• Recouvrements Espèces :', formatGnf(data.creditPaymentsCash), font, fontBold),
                if (data.creditPaymentsMobile > 0)
                  _thermalRow('• Recouvrements Mobile :', formatGnf(data.creditPaymentsMobile), font, font),
                _thermalRow('Total Créances Récupérées :', formatGnf(data.totalCreditPayments), fontBold, fontBold),
              ],

              pw.SizedBox(height: 5),
              pw.Divider(thickness: 0.6, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 3),

              // ── 3. Dépenses & Décaissements ──
              pw.Text('4. DÉCAISSEMENTS & SORTIES', style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
              pw.SizedBox(height: 3),
              _thermalRow('• Dépenses d\'exploitation :', formatGnf(data.expensesCash), font, font),
              _thermalRow('• Achats & Fournisseurs :', formatGnf(data.purchasesCash + data.supplierPaymentsCash), font, font),
              _thermalRow('• Retraits caisse :', formatGnf(data.manualOutflowCash), font, font),
              _thermalRow('Total Décaissé Espèces :', '-${formatGnf(data.totalOutflowCash)}', fontBold, fontBold),

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1.2),
              pw.SizedBox(height: 4),

              // ── 4. Rapprochement Tiroir-Caisse ──
              pw.Center(
                child: pw.Text(
                  'RAPPROCHEMENT DU TIROIR-CAISSE',
                  style: pw.TextStyle(font: fontBold, fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 4),
              _thermalRow('Fond de caisse départ :', formatGnf(data.openingBalance), font, font),
              _thermalRow('+ Entrées espèces du jour :', formatGnf(data.totalInflowCash), font, font),
              _thermalRow('- Sorties espèces du jour :', formatGnf(data.totalOutflowCash), font, font),
              pw.SizedBox(height: 3),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.8),
                  borderRadius: pw.BorderRadius.circular(2),
                ),
                child: _thermalRow('SOLDE THÉORIQUE :', formatGnf(data.theoreticalCash), fontBold, fontBold),
              ),
              pw.SizedBox(height: 3),
              _thermalRow('ESPÈCES COMPTÉES :', formatGnf(data.countedCash), fontBold, fontBold),
              pw.SizedBox(height: 3),
              _thermalEcartRow(data.discrepancy, fontBold),

              // ── Billetterie détaillée (si présente) ──
              if (data.denominations.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.6, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 3),
                pw.Text('DÉTAIL DE LA BILLETTERIE', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                pw.SizedBox(height: 2),
                ...data.denominations.entries.where((e) => e.value > 0).map((entry) {
                  final coupure = entry.key;
                  final count = entry.value;
                  final total = coupure * count;
                  return _thermalRow(
                    '${formatAmount(coupure)} GNF x $count :',
                    formatGnf(total),
                    font,
                    font,
                  );
                }),
              ],

              // ── Notes & Observations ──
              if (data.notes.trim().isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.6, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 3),
                pw.Text('OBSERVATIONS DU CAISSIER :', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                pw.SizedBox(height: 2),
                pw.Text(
                  data.notes.trim(),
                  style: pw.TextStyle(font: font, fontSize: 7.5, fontStyle: pw.FontStyle.italic),
                ),
              ],

              pw.SizedBox(height: 10),
              pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 6),

              // ── Signatures ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Visa Caissier :', style: pw.TextStyle(font: fontBold, fontSize: 7.5)),
                      pw.SizedBox(height: 22),
                      pw.Container(width: 80, height: 0.5, color: PdfColors.black),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Visa Gérant :', style: pw.TextStyle(font: fontBold, fontSize: 7.5)),
                      pw.SizedBox(height: 22),
                      pw.Container(width: 80, height: 0.5, color: PdfColors.black),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Text(
                  'N\'MaShop Desktop • Clôture Certifiée',
                  style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.grey700),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  '${dateFmt.format(data.generatedAt)} ${timeFmt.format(data.generatedAt)}',
                  style: pw.TextStyle(font: font, fontSize: 6.5, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// ─── 2. FORMAT OFFICIEL A4 (PDF) ──────────────────────────────────────────
  static Future<Uint8List> generateA4ZReportPdf(ZReportData data) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    const navyColor = PdfColor.fromInt(0xFF0F1B3D);
    const orangeColor = PdfColor.fromInt(0xFFE85D04);
    const emeraldColor = PdfColor.fromInt(0xFF10B981);
    const redColor = PdfColor.fromInt(0xFFEF4444);

    final dayFmt = DateFormat('dd/MM/yyyy HH:mm', 'fr');
    final dateOnlyFmt = DateFormat('dd/MM/yyyy', 'fr');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return [
            // ── En-tête officiel ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      data.businessName.toUpperCase(),
                      style: pw.TextStyle(font: fontBold, fontSize: 18, color: navyColor),
                    ),
                    pw.SizedBox(height: 4),
                    if (data.businessAddress.isNotEmpty)
                      pw.Text(data.businessAddress, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey800)),
                    if (data.businessPhone.isNotEmpty)
                      pw.Text('Tél : ${data.businessPhone}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey800)),
                    if (data.businessNif.isNotEmpty)
                      pw.Text('NIF : ${data.businessNif}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey800)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: pw.BoxDecoration(
                        color: navyColor,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'RAPPORT DE CLÔTURE DE CAISSE (Z)',
                        style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('Journée du : ${dateOnlyFmt.format(data.date)}', style: pw.TextStyle(font: fontBold, fontSize: 10, color: orangeColor)),
                    pw.Text('Édité le : ${dayFmt.format(data.generatedAt)}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                    pw.Text('Opérateur : ${data.cashierName}', style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: navyColor)),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 12),
            pw.Container(height: 2.5, color: orangeColor),
            pw.SizedBox(height: 16),

            // ── Synthèse des Indicateurs Clés ──
            pw.Text('SYNTHÈSE DE LA JOURNÉE', style: pw.TextStyle(font: fontBold, fontSize: 11, color: navyColor)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Indicateur', 'Montant', 'Détails / Volume'],
              data: [
                ['Chiffre d\'Affaires Total', formatGnf(data.totalRevenue), '${data.totalSalesCount} ventes réalisées'],
                ['Total Encaissé (Toutes voies)', formatGnf(data.totalCollectedToday), 'Espèces, MoMo, Banque, Recouvrements'],
                ['Total Décaissements Espèces', formatGnf(data.totalOutflowCash), 'Dépenses, Achats, Retraits'],
                ['Solde Théorique du Tiroir', formatGnf(data.theoreticalCash), 'Solde calculé par le système'],
                ['Espèces Physiques Comptées', formatGnf(data.countedCash), 'Montant déclaré par l\'opérateur'],
                [
                  'Écart de Caisse',
                  data.discrepancy > 0 ? '+${formatGnf(data.discrepancy)}' : formatGnf(data.discrepancy),
                  data.discrepancy == 0
                      ? 'Caisse parfaitement équilibrée'
                      : (data.discrepancy > 0 ? 'Excédent de caisse' : 'Déficit / Manquant de caisse'),
                ],
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

            pw.SizedBox(height: 16),

            // ── Tableau Ventes par Mode de Règlement ──
            pw.Text('DÉTAIL DU CHIFFRE D\'AFFAIRES & RÈGLEMENTS', style: pw.TextStyle(font: fontBold, fontSize: 11, color: navyColor)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Canal / Mode de Règlement', 'Montant Encaissé', 'Part / Statut'],
              data: [
                [
                  'Espèces (Cash)',
                  formatGnf(data.cashSales),
                  data.totalRevenue > 0 ? '${((data.cashSales / data.totalRevenue) * 100).toStringAsFixed(1)}%' : '0%'
                ],
                [
                  'Mobile Money (Orange Money, MTN MoMo)',
                  formatGnf(data.mobileMoneySales),
                  data.totalRevenue > 0 ? '${((data.mobileMoneySales / data.totalRevenue) * 100).toStringAsFixed(1)}%' : '0%'
                ],
                [
                  'Virement / Banque / Chèque',
                  formatGnf(data.bankSales),
                  data.totalRevenue > 0 ? '${((data.bankSales / data.totalRevenue) * 100).toStringAsFixed(1)}%' : '0%'
                ],
                [
                  'Ventes à Crédit (Restes dûs à recouvrer)',
                  formatGnf(data.creditSales),
                  'Créances nées ce jour'
                ],
                [
                  'Recouvrements de créances antérieures (Espèces)',
                  formatGnf(data.creditPaymentsCash),
                  'Entrée de trésorerie'
                ],
              ],
              border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF334155)),
              cellStyle: pw.TextStyle(font: font, fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerLeft,
              },
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),

            pw.SizedBox(height: 16),

            // ── Tableau Audit & Réconciliation Caisse ──
            pw.Text('AUDIT DU TIROIR-CAISSE (ESPÈCES PHYSIQUES)', style: pw.TextStyle(font: fontBold, fontSize: 11, color: navyColor)),
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
                  _pdfSummaryRow('Fond de caisse de départ (Ouverture)', formatGnf(data.openingBalance), fontBold, navyColor),
                  _pdfSummaryRow('Total Entrées physiques en espèces', '+ ${formatGnf(data.totalInflowCash)}', font, emeraldColor),
                  _pdfSummaryRow('Total Décaissements physiques en espèces', '- ${formatGnf(data.totalOutflowCash)}', font, redColor),
                  pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                  _pdfSummaryRow('SOLDE THÉORIQUE DU TIROIR-CAISSE', formatGnf(data.theoreticalCash), fontBold, navyColor, isTitle: true),
                  _pdfSummaryRow('MONTANT RÉELLEMENT COMPTÉ', formatGnf(data.countedCash), fontBold, emeraldColor, isTitle: true),
                  pw.Divider(color: PdfColors.grey400, thickness: 1),
                  _pdfSummaryRow(
                    'ÉCART CONSTATÉ (RÉEL - THÉORIQUE)',
                    data.discrepancy > 0 ? '+${formatGnf(data.discrepancy)}' : formatGnf(data.discrepancy),
                    fontBold,
                    data.discrepancy == 0 ? emeraldColor : (data.discrepancy > 0 ? orangeColor : redColor),
                    isTitle: true,
                  ),
                ],
              ),
            ),

            // ── Billetterie détaillée si disponible ──
            if (data.denominations.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Text('DÉTAIL DU COMPTAGE PAR COUPURES (BILLETTERIE)', style: pw.TextStyle(font: fontBold, fontSize: 10, color: navyColor)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['Coupure / Billet', 'Quantité Comptée', 'Sous-Total'],
                data: [
                  for (final entry in data.denominations.entries)
                    if (entry.value > 0)
                      [
                        '${formatAmount(entry.key)} GNF',
                        '${entry.value} billets',
                        formatGnf(entry.key * entry.value),
                      ]
                ],
                border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
                headerStyle: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF475569)),
                cellStyle: pw.TextStyle(font: font, fontSize: 8.5),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerRight,
                },
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ],

            // ── Observations ──
            if (data.notes.trim().isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Text('OBSERVATIONS ET JUSTIFICATIONS DU CAISSIER', style: pw.TextStyle(font: fontBold, fontSize: 10, color: navyColor)),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF1F5F9),
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColor.fromInt(0xFFCBD5E1)),
                ),
                child: pw.Text(data.notes.trim(), style: pw.TextStyle(font: font, fontSize: 9)),
              ),
            ],

            pw.SizedBox(height: 24),

            // ── Signatures & Décharges ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Visa & Décharge de l\'Opérateur / Caissier :', style: pw.TextStyle(font: fontBold, fontSize: 9, color: navyColor)),
                    pw.SizedBox(height: 4),
                    pw.Text('Nom : ${data.cashierName}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                    pw.SizedBox(height: 24),
                    pw.Container(width: 170, height: 0.5, color: PdfColors.grey500),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Visa, Contrôle & Cachet de la Direction :', style: pw.TextStyle(font: fontBold, fontSize: 9, color: navyColor)),
                    pw.SizedBox(height: 4),
                    pw.Text('Contrôlé conforme le ${dateOnlyFmt.format(data.generatedAt)}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
                    pw.SizedBox(height: 24),
                    pw.Container(width: 170, height: 0.5, color: PdfColors.grey500),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 24),

            // ── Footer ──
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF1F5F9),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Clôture Certifiée — ${data.businessName}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
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

  // ── Helpers ──
  static pw.Widget _thermalRow(String label, String value, pw.Font fontLabel, pw.Font fontVal) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: fontLabel, fontSize: 8)),
          pw.Text(value, style: pw.TextStyle(font: fontVal, fontSize: 8)),
        ],
      ),
    );
  }

  static pw.Widget _thermalEcartRow(int ecart, pw.Font fontBold) {
    String label;
    PdfColor color;
    if (ecart == 0) {
      label = 'ÉCART : 0 GNF (ÉQUILIBRÉ)';
      color = PdfColors.black;
    } else if (ecart > 0) {
      label = 'ÉCART : +${formatGnf(ecart)} (EXCÉDENT)';
      color = PdfColors.black;
    } else {
      label = 'ÉCART : ${formatGnf(ecart)} (MANQUANT)';
      color = PdfColors.black;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 1),
        borderRadius: pw.BorderRadius.circular(2),
      ),
      child: pw.Center(
        child: pw.Text(
          label,
          style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: color),
        ),
      ),
    );
  }

  static pw.Widget _pdfSummaryRow(String label, String value, pw.Font font, PdfColor color, {bool isTitle = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: font,
              fontSize: isTitle ? 10.5 : 9,
              color: isTitle ? PdfColors.black : PdfColors.grey800,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: isTitle ? 11 : 9,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
