# Base de Données (Drift / SQLite)

N'MaShop est conçu pour fonctionner hors-ligne (Offline-First) grâce à une base de données locale propulsée par le package **Drift** (sur-couche de SQLite).

## Emplacement des Fichiers

- La configuration de la base se trouve dans : `lib/core/database/database.dart`
- Les définitions des tables se trouvent dans : `lib/core/database/tables/`
- Le fichier généré automatiquement par Drift : `lib/core/database/database.g.dart` (À ne pas modifier manuellement).

> **Important :** Le fichier physique de la base de données est sauvegardé sous le nom `gescompta.sqlite` dans le dossier des documents locaux de l'application.

## Schéma Principal

### 1. Utilisateurs (`users`)
Gère les accès (Comptes).
- `id` : UUID unique.
- `username` / `passwordHash` : Identifiants.
- `role` : Différencie l'accès Administrateur vs Vendeur.

### 2. Produits (`products`)
Le catalogue d'inventaire.
- `id`, `name`, `reference`, `unit` : Informations de base.
- `purchasePrice`, `salePrice` : Prix (stockés sous forme d'entiers - GNF).
- `stockQuantity`, `lowStockThreshold` : Gestion de l'inventaire.

### 3. Ventes (`sales` & `sale_items`)
Les transactions avec les clients.
- `sales` : Entête de la facture (Total, Montant payé, Client).
- `sale_items` : Les lignes de détail (Produit, Quantité, Prix Unitaire).

### 4. Flux de Caisse (`cash_movements`)
Les mouvements financiers.
- Permet de tracer chaque encaissement (lié à une vente) ou décaissement.

## Intégrité et Migrations

L'intégrité référentielle (`PRAGMA foreign_keys = ON`) est activée par défaut. 
Lors d'une mise à jour de la structure (ajout d'une colonne), la méthode `migration` dans `AppDatabase` s'assure de l'application des requêtes `ALTER TABLE` sans perte de données.
