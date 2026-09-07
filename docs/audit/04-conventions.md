# Conventions de Développement et Standards du Projet

*Manuel de normes d'écriture de code et de gestion de version.*

Ce document établit les règles strictes de développement sur N'MaShop :
homogénéité du code, travail en équipe facilité, revues simplifiées.

---

## 1. Organisation des dossiers (arborescence standard)

Chaque feature majeure respecte scrupuleusement la structure suivante sous
`lib/features/<nom_feature>/` :

```
lib/features/<nom_feature>/
├── application/             # Gestion d'état et contrôleurs d'UI
│   ├── <feature>_providers.dart
│   └── <feature>_controller.dart
├── domain/                  # Cœur métier pur (sans Flutter ni Drift)
│   ├── entities/
│   ├── repositories/        # Interfaces abstraites
│   └── use_cases/           # Cas d'usage uniques
├── data/                    # Implémentations d'infrastructure
│   ├── models/              # Modèles Drift ou DTOs
│   ├── repositories/        # Implémentations concrètes
│   └── services/            # Services de données (ex. calculs SQL)
└── presentation/            # Widgets et écrans Flutter
    ├── screens/             # Pages complètes (Scaffolds)
    └── widgets/             # Sous-composants locaux réutilisables
```

> Les widgets transverses réutilisables dans toute l'app vont dans `lib/core/widgets/`.

---

## 2. Conventions de nommage

- **Fichiers** — `snake_case` : `product_repository.dart`, `products_screen.dart`,
  `record_sale_use_case.dart`.
- **Classes** — `UpperCamelCase` :
  - Widgets suffixés par leur type : `ProductsScreen` (page), `ProductCard`
    (composant).
  - Repository — interface : `<Nom>Repository` (`ProductRepository`) ;
    implémentation Drift : `Drift<Nom>Repository` (`DriftProductRepository`).
  - Use Cases — verbe d'action : `RecordSaleUseCase`.
  - Controllers/Notifiers — suffixe `Controller`/`Notifier` : `SaleCartController`.
- **Variables/méthodes** — `lowerCamelCase` : `totalAmount`, `stockQuantity`,
  `calculateCmp()`.
- **Providers Riverpod** — suffixe `Provider` en `lowerCamelCase` :
  `databaseProvider`, `themeProvider`, `productRepositoryProvider`.

---

## 3. Style de code et bonnes pratiques

- **Interface ≠ implémentation dans le même fichier** : jamais d'implémentation
  concrète de base dans le fichier de l'interface de domaine.
- **Constructeurs `const`** partout où le widget/objet est immuable.
- **Imports** : relatifs à l'intérieur d'une même feature
  (`import '../domain/entities/product.dart';`) ; `package:` uniquement pour les
  dépendances externes et `core/`.

---

## 4. Git & commits (Conventional Commits)

Format : `<type>(<scope>): <description>`

| Type | Usage | Exemple |
|------|-------|---------|
| `feat` | nouvelle fonctionnalité métier | `feat(sales): print invoice receipt` |
| `fix` | correction de bogue | `fix(stock): prevent negative stock on manual adjustment` |
| `docs` | documentation | `docs(architecture): complete target architecture doc` |
| `style` | formatage, sans changement logique | `style: fix imports order in app_card.dart` |
| `refactor` | restructuration sans changement fonctionnel | `refactor(stock): move product forms to separate widgets` |
| `test` | tests unitaires | `test(sales): add unit tests for RecordSaleUseCase` |
| `chore` | maintenance / configuration | `chore: upgrade riverpod to v3.3.2` |

---

## 5. Documentation technique (docstrings)

Toutes les interfaces publiques (classes exposées, méthodes de repositories, use
cases, providers) sont commentées avec le format `///` de Dart.

Chaque Use Case comporte :

- une description en français de son rôle ;
- une section `/// **Règles métier appliquées :**` listant les identifiants de
  règles ;
- la description des paramètres attendus et du retour.

```dart
/// Enregistre une vente comptant ou à crédit dans le système.
///
/// **Règles métier appliquées :**
/// * [RULE-001] (Stock négatif interdit)
/// * [RULE-010] (Client obligatoire pour vente crédit)
/// * [RULE-030] (Équilibre de la pièce comptable)
class RecordSaleUseCase {
  // ...
}
```

---

## Clôture — Conventions

### Incohérences détectées

- **Lints permissifs** : pas de config `analysis_options.yaml` stricte, ce qui a
  laissé passer imports inutilisés et syntaxes dépréciées (`withOpacity`).
- **Commits peu structurés** : l'historique contient des messages non conformes
  (« ui refactoring », « dark mode toggle »). Les Conventional Commits
  s'appliquent aux futures branches.

### Risques

- **Résistance au changement** : imposer Use Cases + docstrings peut ralentir le
  prototypage rapide, mais c'est le seul moyen de garantir la pérennité.

### Questions ouvertes

- **Pre-commit hooks (Lefthook)** pour rejeter automatiquement lints non résolus
  et commits non conformes ?
- **Seuil de couverture de tests** (ex. 80 %) sur la couche Domaine (use cases,
  entités) par Pull Request ?

### Décisions à prendre

1. Ajouter une **config linter stricte** (`flutter_lints` renforcé ou
   `very_good_analysis`).
2. Exiger **100 % de couverture de tests unitaires** sur tous les Use Cases
   comptables et de stocks avant mise en production.
