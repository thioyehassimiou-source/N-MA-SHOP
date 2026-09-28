import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/payment_method.dart';
import '../../stock/domain/entities/product.dart';
import '../domain/purchase_draft.dart';
import 'suppliers_providers.dart';

/// Une ligne d'achat dans le panier.
class PurchaseCartLine {
  const PurchaseCartLine({
    required this.productId,
    required this.name,
    required this.unit,
    required this.unitPrice,
    required this.quantity,
    required this.currentStock,
    required this.currentCmp,
    this.imageUrl,
  });

  final String productId;
  final String name;
  final String unit;
  final int unitPrice;
  final int quantity;
  final int currentStock;
  final int currentCmp;
  final String? imageUrl;

  int get lineTotal => unitPrice * quantity;

  /// Calcule le futur CMP si cet achat est validé
  int get projectedCmp {
    final newStock = currentStock + quantity;
    if (newStock == 0) return currentCmp;
    final totalValue = (currentStock * currentCmp) + (quantity * unitPrice);
    return (totalValue / newStock).round();
  }

  PurchaseCartLine copyWith({int? unitPrice, int? quantity, String? imageUrl}) =>
      PurchaseCartLine(
        productId: productId,
        name: name,
        unit: unit,
        unitPrice: unitPrice ?? this.unitPrice,
        quantity: quantity ?? this.quantity,
        currentStock: currentStock,
        currentCmp: currentCmp,
        imageUrl: imageUrl ?? this.imageUrl,
      );
}

/// État de l'écran Nouvel Achat.
class PurchaseCartState {
  const PurchaseCartState({
    this.lines = const [],
    this.method = PaymentMethod.cash,
    this.supplierName = '',
    this.amountPaid = 0,
    this.submitting = false,
  });

  final List<PurchaseCartLine> lines;
  final PaymentMethod method;
  final String supplierName;
  final int amountPaid;
  final bool submitting;

  int get total => lines.fold(0, (s, l) => s + l.lineTotal);
  bool get isEmpty => lines.isEmpty;

  PurchaseCartState copyWith({
    List<PurchaseCartLine>? lines,
    PaymentMethod? method,
    String? supplierName,
    int? amountPaid,
    bool? submitting,
  }) => PurchaseCartState(
    lines: lines ?? this.lines,
    method: method ?? this.method,
    supplierName: supplierName ?? this.supplierName,
    amountPaid: amountPaid ?? this.amountPaid,
    submitting: submitting ?? this.submitting,
  );
}

/// Contrôleur du panier d'achat.
class PurchaseCartController extends Notifier<PurchaseCartState> {
  @override
  PurchaseCartState build() => const PurchaseCartState();

  void addProduct(Product product) {
    final index = state.lines.indexWhere((l) => l.productId == product.id);
    final lines = [...state.lines];
    if (index >= 0) {
      final line = lines[index];
      lines[index] = line.copyWith(quantity: line.quantity + 1);
    } else {
      lines.add(
        PurchaseCartLine(
          productId: product.id,
          name: product.name,
          unit: product.unit,
          imageUrl: product.imageUrl,
          unitPrice: product
              .purchasePrice, // Par défaut, on propose le dernier prix d'achat
          quantity: 1,
          currentStock: product.stockQuantity,
          currentCmp: product.weightedAverageCost,
        ),
      );
    }
    state = state.copyWith(lines: lines);
  }

  void setQuantity(int index, int quantity) {
    if (quantity <= 0) return removeLine(index);
    final lines = [...state.lines];
    lines[index] = lines[index].copyWith(quantity: quantity);
    state = state.copyWith(lines: lines);
  }

  void setUnitPrice(int index, int unitPrice) {
    final lines = [...state.lines];
    lines[index] = lines[index].copyWith(unitPrice: unitPrice);
    state = state.copyWith(lines: lines);
  }

  void removeLine(int index) {
    final lines = [...state.lines]..removeAt(index);
    state = state.copyWith(lines: lines);
  }

  void setMethod(PaymentMethod method) =>
      state = state.copyWith(method: method);

  void setSupplierName(String name) =>
      state = state.copyWith(supplierName: name);

  void setAmountPaid(int amount) => state = state.copyWith(amountPaid: amount);

  void clear() => state = const PurchaseCartState();

  Future<String?> submit() async {
    if (state.isEmpty) return 'Le panier est vide.';
    if (state.supplierName.trim().isEmpty) {
      return 'Veuillez saisir un fournisseur.';
    }
    if (state.amountPaid > state.total) {
      return 'Le montant payé ne peut dépasser le total.';
    }
    if (state.submitting) return 'Enregistrement en cours...';

    state = state.copyWith(submitting: true);
    try {
      final draft = PurchaseDraft(
        supplierName: state.supplierName.trim(),
        lines: [
          for (final l in state.lines)
            PurchaseDraftLine(
              productId: l.productId,
              quantity: l.quantity,
              unitPrice: l.unitPrice,
            ),
        ],
        amountPaid: state.amountPaid,
        paymentMethod: state.method,
      );

      await ref.read(purchaseServiceProvider).recordPurchase(draft);

      // Rafraîchir les données
      ref.invalidate(supplierSummariesProvider);
      ref.invalidate(recentPurchasesProvider);

      state = const PurchaseCartState();
      return null; // Succès
    } catch (e) {
      return e.toString();
    } finally {
      if (state.submitting) state = state.copyWith(submitting: false);
    }
  }
}

final purchaseCartControllerProvider =
    NotifierProvider<PurchaseCartController, PurchaseCartState>(
      PurchaseCartController.new,
    );
