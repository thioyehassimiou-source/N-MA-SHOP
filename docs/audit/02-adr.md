# Journal des Décisions d'Architecture (ADR)

*Architecture Decision Records.*

Ce document consigne les décisions architecturales et techniques structurantes de
N'MaShop. Chaque décision est justifiée par son contexte, ses alternatives
rejetées, ses avantages, ses inconvénients et ses impacts.

---

## ADR-001 : Stockage local (offline-first) avec Drift/SQLite

- **Statut :** Accepté
- **Contexte :** l'app cible les petits commerces en Guinée / Afrique de l'Ouest.
  L'accès Internet y est instable, coûteux, sujet à coupures. L'app doit facturer,
  approvisionner et tourner 100 % hors-ligne.
- **Options envisagées :**
  1. Backend API REST + base distante (PostgreSQL), mode déconnecté partiel.
  2. Base locale NoSQL (Hive / Isar).
  3. Base locale relationnelle SQLite via Drift ORM — **Retenu**.
- **Rejet des alternatives :**
  - *API REST Cloud* : la facturation bloque si la connexion lâche ; resync
    bidirectionnelle disproportionnée pour un MVP mono-poste.
  - *NoSQL* : gère mal les relations complexes et jointures, or la comptabilité
    (double entrée, comptes, journaux) est intrinsèquement relationnelle.
- **Avantages :** indépendance réseau, lecture/écriture locale instantanée,
  requêtes relationnelles riches, requêtes typées Drift + détection des bogues SQL
  à la compilation + migrations saines.
- **Inconvénients / risques :** perte de données si panne matérielle définitive
  (→ plan d'export/sauvegarde USB dans la roadmap) ; pas de partage temps réel
  multi-postes (limitation acceptée V1).
- **Impacts :** le schéma de base local est **le point de vérité unique**.

---

## ADR-002 : Standardisation sur la Clean Architecture simplifiée

- **Statut :** Accepté
- **Contexte :** double architecture — `sales` en Clean, `stock` en MVC plat
  (accès Drift direct dans les widgets). Dualité incohérente, difficile à tester,
  couplant l'UI au moteur SQLite.
- **Options envisagées :**
  1. Garder la dualité.
  2. Tout migrer vers MVC plat (supprimer Use Cases/interfaces de `sales`).
  3. Standardiser tout vers la Clean Architecture — **Retenu**.
- **Rejet des alternatives :**
  - *Dualité* : confusion pour les nouveaux devs, incohérence.
  - *MVC plat* : rend impossibles les tests unitaires métier sans Flutter/Drift ;
    couple les vues à l'infrastructure.
- **Avantages :** découplage total (logique métier — CMP, SYSCOHADA — isolée en
  Dart pur), testabilité maximale (mocks de repos), pérennité (changer l'UI ou la
  DB sans toucher au métier).
- **Inconvénients :** boilerplate supplémentaire (interfaces, impls, use cases).
- **Impacts :** **imports Drift/DB interdits dans la couche présentation.**
  Refactoring requis pour `stock` et `settings` en V1.0.

---

## ADR-003 : Riverpod pour l'état et l'injection

- **Statut :** Accepté
- **Contexte :** Flutter a besoin d'un outil pour propager l'état et injecter les
  dépendances (repositories, use cases) proprement.
- **Options envisagées :**
  1. `provider`.
  2. `flutter_bloc`.
  3. Riverpod — **Retenu**.
- **Rejet des alternatives :**
  - *Provider* : dépendance au `BuildContext`, erreurs silencieuses si un provider
    manque dans l'arbre.
  - *Bloc* : rigoureux mais boilerplate massif pour une petite équipe.
- **Avantages :** sécurité à la compilation, indépendance du `BuildContext`
  (écoute hors widgets), facilité de test (override de providers).
- **Inconvénients :** courbe d'apprentissage (autoDispose, watch vs read).
- **Impacts :** **Riverpod = unique brique d'état + injection de dépendances.**

---

## ADR-004 : Retrait de l'IA générative du MVP

- **Statut :** Accepté
- **Contexte :** le projet initial prévoyait des saisies de ventes assistées par
  IA (assistant virtuel, reconnaissance d'intention).
- **Options envisagées :**
  1. Conserver l'IA en V1.
  2. Reporter/supprimer l'IA — **Retenu**.
- **Rejet de l'option 1 :** l'IA exige une connexion permanente (viole l'ADR-001)
  ou des modèles locaux lourds incompatibles avec les PC de boutique d'entrée de
  gamme ; risque d'erreur d'interprétation incompatible avec un grand livre.
- **Avantages :** concentration sur la rigueur comptable et la performance locale ;
  allègement des dépendances et des coûts d'infra.
- **Impacts :** **retirer toute référence à l'IA** de la communication, du
  `pubspec.yaml`, de la description projet et de la roadmap du MVP.

---

## Clôture — Décisions

### Incohérences détectées

- **Divergence marketing vs technique** : les métadonnées mentionnent encore une
  « comptabilité assistée par IA », exclue par l'ADR-004. À nettoyer
  (`pubspec.yaml`, description projet, `README.md`) avant la V1.0.

### Risques

- **Dette de migration** : forcer la Clean Architecture (ADR-002) exige de
  modifier `products_screen.dart` et `suppliers_screen.dart`. À réaliser avec
  précaution pour éviter les régressions sur le catalogue existant.

### Questions ouvertes

- **Chiffrement de la base (ADR-001)** : reporté V1.1. Les premiers utilisateurs
  V1.0 auront donc une base en clair. Acceptable pour le lancement ?
- **Lettrage / sous-comptes tiers** : comment garantir un export propre vers un
  logiciel de cabinet (SAGE) si les comptes tiers (411 Diallo, 411 Barry) ne sont
  pas individualisés en sous-comptes à 6 chiffres ?

### Décisions à prendre

1. Confirmer un **registre d'ADR partagé dans le dépôt** (ce dossier) pour tout
   futur choix technique majeur (générateur PDF, package de chiffrement…).
2. Valider que la **Clean Architecture sur le catalogue produits** sera la
   première tâche de la phase V1.0.
