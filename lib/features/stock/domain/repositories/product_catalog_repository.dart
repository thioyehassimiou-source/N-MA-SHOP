import '../entities/product.dart';
import '../entities/product_draft.dart';

/// Accès au catalogue produits (lecture réactive + écriture).
///
/// La couche présentation ne parle qu'à cette interface via les cas d'usage ;
/// elle ignore que les données vivent dans Drift/SQLite.
abstract interface class ProductCatalogRepository {
  /// Flux réactif de tous les produits, triés par nom.
  Stream<List<Product>> watchAll();

  /// Crée un nouveau produit. Le coût moyen pondéré initial est aligné sur le
  /// prix d'achat.
  Future<void> create(ProductDraft draft);

  /// Met à jour la fiche du produit [id]. N'altère pas le coût moyen pondéré
  /// ni le statut d'activation.
  Future<void> update(String id, ProductDraft draft);

  /// Supprime définitivement un produit et ses mouvements associés du catalogue.
  Future<void> delete(String id);
}
