import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/stock/domain/entities/product.dart';
import '../format/formatters.dart';

class BarcodePrinterService {
  /// Imprime une étiquette thermique pour un produit donné.
  /// Format standard d'étiquette de code-barres : environ 50mm x 30mm
  static Future<void> printProductLabel(Product product) async {
    final doc = pw.Document();

    // Générer un code si le produit n'en a pas (utilisation de l'ID ou de la référence)
    final codeToPrint = (product.barcode?.trim().isNotEmpty == true)
        ? product.barcode!.trim()
        : (product.reference?.trim().isNotEmpty == true
            ? product.reference!.trim()
            : product.id.substring(0, 8).toUpperCase());

    // Format personnalisé pour imprimante thermique (ex: 50x30 mm)
    // 1 mm = 2.83465 points
    final pageFormat = const PdfPageFormat(
      50 * 2.83465,
      30 * 2.83465,
      marginAll: 2 * 2.83465, // Marge de 2mm
    );

    // Charger une police si nécessaire, ou utiliser les polices par défaut de pdf
    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Nom du produit
              pw.Text(
                product.name,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                textAlign: pw.TextAlign.center,
              ),
              // Code-barres
              pw.Expanded(
                child: pw.Center(
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: codeToPrint,
                    width: pageFormat.availableWidth * 0.8,
                    height: pageFormat.availableHeight * 0.45,
                    drawText: true,
                    textStyle: const pw.TextStyle(fontSize: 6),
                  ),
                ),
              ),
              // Prix (optionnel, souvent utile sur une étiquette)
              pw.Text(
                'Prix: ${formatAmount(product.salePrice)}',
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Etiquette_${product.name}',
    );
  }
}
