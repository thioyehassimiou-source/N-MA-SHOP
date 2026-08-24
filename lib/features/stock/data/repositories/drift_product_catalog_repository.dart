import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

// La classe Drift générée `Product` est masquée : la couche data expose
// exclusivement l'entité de domaine du même nom.
import '../../../../core/database/database.dart' hide Product;
import '../../domain/entities/product.dart';
import '../../domain/entities/product_draft.dart';
import '../../domain/repositories/product_catalog_repository.dart';

/// Implémentation Drift de [ProductCatalogRepository].
class DriftProductCatalogRepository implements ProductCatalogRepository {
  DriftProductCatalogRepository(this._db, {String Function()? idGenerator})
    : _newId = idGenerator ?? (() => const Uuid().v4());

  final AppDatabase _db;
  final String Function() _newId;

  @override
  Stream<List<Product>> watchAll() {
    return (_db.select(
      _db.products,
    )..orderBy([(t) => OrderingTerm(expression: t.name)])).watch().map(
      (rows) => rows
          .map(
            (r) => Product(
              id: r.id,
              name: r.name,
              reference: r.reference,
              unit: r.unit,
              purchasePrice: r.purchasePrice,
              salePrice: r.salePrice,
              stockQuantity: r.stockQuantity,
              lowStockThreshold: r.lowStockThreshold,
              weightedAverageCost: r.weightedAverageCost,
              isActive: r.isActive,
              imageUrl: r.imageUrl,
              barcode: r.barcode,
              createdAt: r.createdAt,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<void> create(ProductDraft draft) async {
    await _db
        .into(_db.products)
        .insert(
          ProductsCompanion.insert(
            id: _newId(),
            name: draft.name.trim(),
            reference: Value(draft.reference),
            unit: Value(draft.unit),
            purchasePrice: Value(draft.purchasePrice),
            salePrice: Value(draft.salePrice),
            stockQuantity: Value(draft.stockQuantity),
            lowStockThreshold: Value(draft.lowStockThreshold),
            imageUrl: Value(draft.imageUrl),
            barcode: Value(draft.barcode),
            // Le CMP initial s'aligne sur le prix d'achat.
            weightedAverageCost: Value(draft.purchasePrice),
          ),
        );
  }

  @override
  Future<void> update(String id, ProductDraft draft) async {
    await (_db.update(_db.products)..where((t) => t.id.equals(id))).write(
      ProductsCompanion(
        name: Value(draft.name.trim()),
        reference: Value(draft.reference),
        unit: Value(draft.unit),
        purchasePrice: Value(draft.purchasePrice),
        salePrice: Value(draft.salePrice),
        stockQuantity: Value(draft.stockQuantity),
        lowStockThreshold: Value(draft.lowStockThreshold),
        imageUrl: Value(draft.imageUrl),
        barcode: Value(draft.barcode),
      ),
    );
  }
}
