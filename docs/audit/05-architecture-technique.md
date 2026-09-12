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

## Clôture — État d'Implémentation et Conformité

### Résolutions Effectuées

- **Couplage UI / Drift résolu** : L'accès aux produits, ventes, clients et statistiques
  passe désormais par des Repositories dédiés (`DriftProductRepository`, `DriftSaleRepository`,
  `DriftDashboardRepository`, `DriftBusinessSummaryRepository`, `DriftSellerRepository`)
  injectés via Riverpod.
- **Requêtes agrégées SQL** : Remplacement des chargements de tables entières en RAM
  par des fonctions SQL d'agrégation (`SUM`, `COUNT`, `AVG`), garantissant une
  empreinte mémoire basse sur les machines modestes.
- **Exécution Isolate** : La base de données s'exécute sur un thread d'arrière-plan
  (`createInBackground`), prévenant tout blocage du rendu UI Flutter à 60 FPS.
- **Règles d'Import 100% Respectées** : 0 violation dans les tests et l'analyseur
  statique (`flutter analyze lib/` vierge).

### Pratiques Validées et Consignées

1. **Riverpod** comme unique source de vérité pour l'injection et l'état réactif.
2. **Architecture étanche** : Tout nouvel écran métier doit consommer un provider
   de cas d'utilisation ou de repository, sans jamais instancier directement de Companion Drift.
3. **Optimisation bas niveau** : Mode WAL, cache mémoire borné à 64 Mo, isolation multithread.
