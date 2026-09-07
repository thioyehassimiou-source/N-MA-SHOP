# Architecture Technique et Flots d'Exécution

*Spécifications de conception logicielle et structure du code.*

Ce document définit les fondations logicielles de N'MaShop. Il s'appuie sur une
Clean Architecture simplifiée pour garantir le découplage des responsabilités, la
testabilité du code métier et la modularité de l'application Flutter.

---

## 1. Modèle de conception en couches

L'application est structurée en **5 couches logicielles étanches**, de la plus
externe (technologique) à la plus interne (métier).

```
┌────────────────────────────────────────────────────────┐
│ UI / Presentation (Widgets Flutter, Composants Thème)   │
└───────────┬────────────────────────────────────────────┘
            │ Écoute et Notifie
            ▼
┌────────────────────────────────────────────────────────┐
│ Application / State Management (Riverpod Notifiers)     │
└───────────┬────────────────────────────────────────────┘
            │ Exécute
            ▼
┌────────────────────────────────────────────────────────┐
│ Domain / Business Logic (Use Cases, Entités, Interfaces)│
└───────────┬────────────────────────────────────────────┘
            │ Appelle (via Abstraction)
            ▼
┌────────────────────────────────────────────────────────┐
│ Data / Infrastructure (Reposit. Impl, Drift, SQLite)    │
└────────────────────────────────────────────────────────┘
```

---

## 2. Responsabilités des composants

### 2.1 UI / Présentation

- **Composants :** Widgets Flutter (`ProductsScreen`, `SalesScreen`, dialogues,
  boutons, tables).
- **Responsabilité :** rendre l'interface, capturer les gestes, afficher l'état
  courant.
- **Règle d'or :** l'UI est **totalement stupide** — aucun calcul financier,
  aucun arrondi, aucune requête DB. Elle délègue tout à la couche Application.

### 2.2 Application

- **Composants :** Providers, Notifiers, Controllers Riverpod
  (`SaleCartController`, `ThemeNotifier`).
- **Responsabilité :** orchestrer l'état de l'UI, appeler les use cases, convertir
  le résultat en état affichable réactif.
- **Règle d'or :** gère la logique de présentation (charger, afficher une erreur,
  désactiver un bouton), délègue la logique métier pure aux Use Cases.

### 2.3 Domaine

- **Composants :** Use Cases (`RecordSaleUseCase`, `RecalculateCmp`), entités
  pures, interfaces de repositories (`ProductRepository`).
- **Responsabilité :** cœur métier — règles pures et règles SYSCOHADA (équilibre
  comptable, variations de stock).
- **Règle d'or :** **100 % indépendant de Flutter, Drift et Riverpod.** Dart pur.
  Définit des contrats d'accès aux données sans savoir comment elles sont stockées.

### 2.4 Données

- **Composants :** implémentations de repositories (`DriftProductRepository`,
  `DriftSaleRepository`), services Drift (`DriftSaleService`), schémas ORM.
- **Responsabilité :** implémenter les interfaces du domaine via des requêtes
  concrètes SQLite/Drift.
- **Règle d'or :** traduit entités ↔ tables et gère l'atomicité des transactions.

### 2.5 Infrastructure

- **Composants :** SQLite natif (`sqlite3_flutter_libs`), routeur global
  (GoRouter), persistance du thème (SharedPreferences).
- **Responsabilité :** briques techniques de bas niveau.

---

## 3. Matrice des dépendances et importations

### 3.1 Dépendances autorisées (flux vers le bas)

- **UI** peut importer : Application (Providers) et Domaine (Entités).
- **Application** peut importer : Domaine (Use Cases, Interfaces, Entités).
- **Domaine** ne peut importer : **RIEN d'autre** (uniquement ses entités et
  interfaces).
- **Data** peut importer : Domaine (pour implémenter les interfaces) et
  Infrastructure (Drift).

### 3.2 Dépendances strictement interdites (violations)

- **UI 🚫 Data/Infrastructure** : un widget (`products_screen.dart`) ne doit
  JAMAIS importer `database.dart`, `drift.dart` ni un repository Drift
  (`drift_product_repository.dart`). Il passe uniquement par un provider.
- **Domain 🚫 Application/UI** : un Use Case ou une entité ne doit JAMAIS importer
  `flutter/material.dart`, `flutter_riverpod` ni un widget.
- **Data 🚫 Application/UI** : un repository/service Drift n'interagit jamais avec
  des contrôleurs graphiques.
- **Application 🚫 Data** : un Notifier ne doit pas instancier une classe Drift
  concrète — il dépend de l'interface injectée par Riverpod.

---

## Clôture — Architecture technique

### Incohérences détectées dans le code actuel

- **Violation majeure `products_screen.dart`** : importe directement `drift` et
  écrit en base via `ProductsCompanion` (≈ lignes 394-415). Violation flagrante de
  la règle 3.2 (UI 🚫 Data).
- **Violation majeure `dashboard_providers.dart`** : les providers de calcul font
  directement `db.select(db.sales).get()` au lieu de passer par des repositories.
- **Domaine** : surveiller le mapping `paymentMethod` (énumération Domaine vs
  entier Drift) ; `syscohada_sale_posting_policy.dart` reste propre pour l'instant.

### Risques

- **Évolution de l'ORM** : remplacer Drift (par Isar/Floor) ou migrer vers une API
  REST obligerait à réécrire la quasi-totalité des écrans à cause de la dispersion
  des appels Drift dans l'UI. Avec l'architecture cible, seul `data/` changerait.
- **Tests unitaires impossibles** : tester la création d'un produit exige
  aujourd'hui de démarrer un widget Flutter complet + SQLite simulé.

### Questions ouvertes

- **Codegen** : imposer `@riverpod` (Riverpod Generator) pour tous les nouveaux
  providers, ou garder la déclaration classique `final provider = ...` ?
- **Gestion des exceptions** : les repositories doivent intercepter les exceptions
  SQLite de bas niveau (unicité violée, PK dupliquée) et renvoyer des exceptions
  Domaine typées (ex. `ProductAlreadyExistsException`).

### Décisions à prendre

1. **Proscrire les accès Drift directs dans les widgets** ; corriger
   `products_screen.dart` et `clients_screen.dart` lors de la refactorisation.
2. Valider l'usage exclusif du générateur `@riverpod` pour les nouveaux providers
   (autoDispose par défaut).
