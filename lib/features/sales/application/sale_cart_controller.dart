import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/payment_method.dart';
import '../../business/application/business_providers.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../stock/domain/entities/product.dart';
import '../domain/entities/sale_draft.dart';
import '../domain/errors.dart';
import '../domain/usecases/record_sale.dart';
import 'sales_providers.dart';

/// Une ligne du panier en cours de saisie.
class CartLine {
  const CartLine({
    required this.productId,
    required this.name,
    required this.unit,
    required this.unitPrice,
    required this.quantity,
    required this.availableStock,
    this.imageUrl,
  });

  final String productId;
  final String name;
  final String unit;
  final int unitPrice;
  final int quantity;
  final int availableStock;
  final String? imageUrl;

  int get lineTotal => unitPrice * quantity;
  bool get exceedsStock => quantity > availableStock;

  CartLine copyWith({int? unitPrice, int? quantity}) => CartLine(
    productId: productId,
    name: name,
    unit: unit,
    unitPrice: unitPrice ?? this.unitPrice,
    quantity: quantity ?? this.quantity,
    availableStock: availableStock,
    imageUrl: imageUrl,
  );
}

/// État de l'écran Vendre.
class SaleCartState {
  const SaleCartState({
    this.lines = const [],
    this.method = PaymentMethod.cash,
    this.customerName = '',
    this.customerPhone = '',
    this.submitting = false,
  });

  final List<CartLine> lines;
  final PaymentMethod method;
  final String customerName;
  final String customerPhone;
  final bool submitting;

  int get total => lines.fold(0, (s, l) => s + l.lineTotal);
  bool get isEmpty => lines.isEmpty;
  bool get isCredit => method == PaymentMethod.credit;
  bool get hasStockIssue => lines.any((l) => l.exceedsStock);

  SaleCartState copyWith({
    List<CartLine>? lines,
    PaymentMethod? method,
    String? customerName,
    String? customerPhone,
    bool? submitting,
  }) => SaleCartState(
    lines: lines ?? this.lines,
    method: method ?? this.method,
    customerName: customerName ?? this.customerName,
    customerPhone: customerPhone ?? this.customerPhone,
    submitting: submitting ?? this.submitting,
  );
}

/// Pilote l'écran Vendre : gère le panier et déclenche le moteur.
/// Aucune règle métier de vente ici — tout passe par le use-case.
class SaleCartController extends Notifier<SaleCartState> {
  @override
  SaleCartState build() => const SaleCartState();

  /// Ajoute un produit au panier (ou incrémente s'il y est déjà).
  void addProduct(Product product) {
    final index = state.lines.indexWhere((l) => l.productId == product.id);
    final lines = [...state.lines];
    if (index >= 0) {
      final line = lines[index];
      lines[index] = line.copyWith(quantity: line.quantity + 1);
    } else {
      lines.add(
        CartLine(
          productId: product.id,
          name: product.name,
          unit: product.unit,
          unitPrice: product.salePrice,
          quantity: 1,
          availableStock: product.stockQuantity,
          imageUrl: product.imageUrl,
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

  void setCustomerName(String name) =>
      state = state.copyWith(customerName: name);

  void setCustomerPhone(String phone) =>
      state = state.copyWith(customerPhone: phone);

  void clear() => state = const SaleCartState();

  /// Enregistre la vente via le moteur. Retourne le résultat typé ; en cas de
  /// succès, remet le panier à zéro et rafraîchit les indicateurs.
  Future<RecordSaleResult> submit() async {
    if (state.isEmpty) return const RecordSaleFailure(EmptySaleError());
    if (state.submitting) {
      return const RecordSaleFailure(
        UnexpectedSaleError('Enregistrement déjà en cours'),
      );
    }

    state = state.copyWith(submitting: true);
    try {
      String? customerId;
      if (state.isCredit) {
        final name = state.customerName.trim();
        if (name.isEmpty) {
          return const RecordSaleFailure(CreditRequiresCustomerError());
        }
        customerId = await ref
            .read(customerRepositoryProvider)
            .getOrCreate(name, phone: state.customerPhone);
      }

      final draft = SaleDraft(
        customerId: customerId,
        lines: [
          for (final l in state.lines)
            SaleDraftLine(
              productId: l.productId,
              quantity: l.quantity,
              unitPrice: l.unitPrice,
            ),
        ],
        tenders: state.isCredit
            ? const []
            : [PaymentTender(method: state.method, amount: state.total)],
      );

      final result = await ref.read(recordSaleUseCaseProvider)(draft);
      if (result is RecordSaleSuccess) {
        // Rafraîchit les vues qui dépendent des ventes.
        ref.invalidate(dashboardDataProvider);
        ref.invalidate(businessSummaryProvider);
        state = const SaleCartState();
      }
      return result;
    } finally {
      if (state.submitting) state = state.copyWith(submitting: false);
    }
  }
}

final saleCartControllerProvider =
    NotifierProvider<SaleCartController, SaleCartState>(SaleCartController.new);
