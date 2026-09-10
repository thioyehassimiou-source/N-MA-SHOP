import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../format/formatters.dart';
import '../../features/equipe/domain/entities/seller_performance.dart';
import '../../features/equipe/domain/repositories/seller_repository.dart';
import '../../features/reports/application/reports_providers.dart';

/// Service responsable de la génération du rapport de performance commercial en PDF.
class PdfSellerReportService {
  static Future<Uint8List> generateSellerReportPdf({
    required SellerPerformance seller,
    required List<SellerSaleItem> sales,
    required List<SellerCustomerItem> customers,
    required ReportRange range,
    required String businessName,
    required String businessPhone,
    required String businessAddress,
  }) async {
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
            // ── En-Tête Boutique & N'MaShop ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      businessName.toUpperCase(),
                      style: pw.TextStyle(
                          font: fontBold, fontSize: 18, color: navyColor),
                    ),
                    pw.SizedBox(height: 4),
                    if (businessAddress.isNotEmpty)
                      pw.Text(businessAddress,
                          style: pw.TextStyle(
                              font: font, fontSize: 9, color: PdfColors.grey800)),
                    if (businessPhone.isNotEmpty)
                      pw.Text('Tél : $businessPhone',
                          style: pw.TextStyle(
                              font: font, fontSize: 9, color: PdfColors.grey800)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: navyColor,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'RAPPORT DE PERFORMANCE COMMERCIALE',
                        style: pw.TextStyle(
                            font: fontBold, fontSize: 10, color: PdfColors.white),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Période : ${range.label}',
                      style: pw.TextStyle(
                          font: fontBold, fontSize: 10, color: orangeColor),
                    ),
                    pw.Text(
                      'Du ${dateOnlyFmt.format(range.start)} au ${dateOnlyFmt.format(range.end.subtract(const Duration(seconds: 1)))}',
                      style: pw.TextStyle(
                          font: font, fontSize: 8, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Édité le : ${dayFmt.format(DateTime.now())}',
                      style: pw.TextStyle(
                          font: font, fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(color: PdfColors.grey300, thickness: 1),
            pw.SizedBox(height: 12),

            // ── Profil du Vendeur ──
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('AGENT COMMERCIAL / VENDEUR',
                          style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 9,
                              color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text(seller.sellerName,
                          style: pw.TextStyle(
                              font: fontBold, fontSize: 14, color: navyColor)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('TAUX DE COMMISSION',
                          style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 9,
                              color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '${seller.commissionRate.toStringAsFixed(1)} %',
                        style: pw.TextStyle(
                            font: fontBold, fontSize: 14, color: orangeColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // ── Indicateurs Clés (KPIs) ──
            pw.Row(
              children: [
                _buildKpiCard(
                  title: 'CHIFFRE D\'AFFAIRES',
                  value: formatGnf(seller.totalRevenue),
                  color: navyColor,
                  fontBold: fontBold,
                  font: font,
                ),
                pw.SizedBox(width: 8),
                _buildKpiCard(
                  title: 'MONTANT ENCAISSÉ',
                  value: formatGnf(seller.totalCollected),
                  color: emeraldColor,
                  fontBold: fontBold,
                  font: font,
                ),
                pw.SizedBox(width: 8),
                _buildKpiCard(
                  title: 'CRÉDITS / IMPAYÉS',
                  value: formatGnf(seller.totalRemaining),
                  color: redColor,
                  fontBold: fontBold,
                  font: font,
                ),
                pw.SizedBox(width: 8),
                _buildKpiCard(
                  title: 'COMMISSION DUE',
                  value: formatGnf(seller.commissionAmount),
                  color: orangeColor,
                  fontBold: fontBold,
                  font: font,
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Ligne secondaire de KPIs
            pw.Row(
              children: [
                _buildSmallKpi('Nombre de ventes', '${seller.salesCount}',
                    fontBold, font),
                pw.SizedBox(width: 8),
                _buildSmallKpi('Panier moyen',
                    formatGnf(seller.averageBasket), fontBold, font),
                pw.SizedBox(width: 8),
                _buildSmallKpi('Clients servis',
                    '${seller.customersServedCount}', fontBold, font),
                pw.SizedBox(width: 8),
                _buildSmallKpi(
                    'Taux recouvrement',
                    '${seller.collectionRate.toStringAsFixed(1)} %',
                    fontBold,
                    font),
              ],
            ),
            pw.SizedBox(height: 20),

            // ── Historique des Ventes ──
            pw.Text(
              'HISTORIQUE DES VENTES RÉALISÉES (${sales.length})',
              style: pw.TextStyle(font: fontBold, fontSize: 11, color: navyColor),
            ),
            pw.SizedBox(height: 8),
            if (sales.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 10),
                child: pw.Text(
                  'Aucune vente réalisée sur cette période.',
                  style: pw.TextStyle(
                      font: font, fontSize: 9, color: PdfColors.grey600),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                border: null,
                headerStyle: pw.TextStyle(
                    font: fontBold, fontSize: 8, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: navyColor),
                headerHeight: 22,
                cellHeight: 20,
                cellStyle: pw.TextStyle(font: font, fontSize: 8),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.centerRight,
                },
                headers: [
                  'RÉFÉRENCE',
                  'DATE',
                  'CLIENT',
                  'TOTAL VENTE',
                  'ENCAISSÉ',
                  'RESTE DÛ',
                ],
                data: sales.take(40).map((s) {
                  return [
                    s.reference,
                    dayFmt.format(s.date),
                    s.customerName,
                    formatGnf(s.totalAmount),
                    formatGnf(s.amountPaid),
                    formatGnf(s.remaining),
                  ];
                }).toList(),
              ),

            pw.SizedBox(height: 20),

            // ── Clients Traités ──
            if (customers.isNotEmpty) ...[
              pw.Text(
                'PRINCIPAUX CLIENTS SERVIS (${customers.length})',
                style: pw.TextStyle(
                    font: fontBold, fontSize: 11, color: navyColor),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                border: null,
                headerStyle: pw.TextStyle(
                    font: fontBold, fontSize: 8, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: navyColor),
                headerHeight: 22,
                cellHeight: 20,
                cellStyle: pw.TextStyle(font: font, fontSize: 8),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
                headers: [
                  'NOM DU CLIENT',
                  'TÉLÉPHONE',
                  'NB ACHATS',
                  'TOTAL ACHATS',
                ],
                data: customers.take(20).map((c) {
                  return [
                    c.name,
                    c.phone ?? '-',
                    '${c.salesCount}',
                    formatGnf(c.totalSpent),
                  ];
                }).toList(),
              ),
            ],

            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 8),

            // ── Signatures ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Signature de l\'agent :',
                        style: pw.TextStyle(
                            font: font, fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 36),
                    pw.Text(seller.sellerName,
                        style: pw.TextStyle(
                            font: fontBold, fontSize: 9, color: navyColor)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Signature de la Direction / Admin :',
                        style: pw.TextStyle(
                            font: font, fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 36),
                    pw.Text('Pour accord et validation',
                        style: pw.TextStyle(
                            font: font, fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildKpiCard({
    required String title,
    required String value,
    required PdfColor color,
    required pw.Font fontBold,
    required pw.Font font,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                  font: fontBold, fontSize: 7, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(font: fontBold, fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildSmallKpi(
      String title, String value, pw.Font fontBold, pw.Font font) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(title,
                style: pw.TextStyle(
                    font: font, fontSize: 7, color: PdfColors.grey700)),
            pw.Text(value,
                style: pw.TextStyle(
                    font: fontBold, fontSize: 8, color: PdfColors.grey900)),
          ],
        ),
      ),
    );
  }
}
