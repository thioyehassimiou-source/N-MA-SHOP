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

## ADR-005 : Système de licence hybride offline-first et délai de grâce de 5 jours

- **Statut :** Accepté et Implémenté
- **Contexte :** En Guinée et en Afrique de l'Ouest, de nombreux commerçants n'ont
  aucune connexion Internet sur leur poste caisse de manière prolongée. Le modèle
  de validation en ligne permanente est inapplicable. En même temps, il faut
  garantir que le logiciel ne soit pas piraté ou dupliqué sans licence valide.
- **Options envisagées :**
  1. Blocage strict en ligne (Heartbeat obligatoire toutes les 24h) — Rejeté.
  2. Licence statique par simple clé produit sans liaison matérielle — Rejeté.
  3. Architecture hybride 3 leviers : obfuscation binaire, signature cryptographique
     asymétrique liée à l'empreinte matérielle (Hardware ID), autonomie 100%
     hors-ligne pendant la durée de validité, extension par délai de grâce de 5 jours
     post-expiration, et synchronisation périodique avec Neon PostgreSQL — **Retenu**.
- **Avantages :** Zéro blocage intempestif en cas de coupure Internet ; protection
  anti-copie physique inviolable (une licence générée pour le PC A refuse de
  s'activer sur le PC B) ; délai de grâce évitant d'interrompre l'activité commerciale
  d'un client avant qu'il n'ait pu contacter le développeur (+224 624 19 30 69).
- **Impacts :** Synchronisation bidirectionnelle des statuts de révocation, module
  Admin Mobile (`apps/admin_mobile`) pour l'émission des licences par QR code/WhatsApp.

---

## ADR-006 : Optimisations de bas niveau pour ordinateurs à ressources modestes

- **Statut :** Accepté et Implémenté
- **Contexte :** Les commerçants utilisent fréquemment d'anciens ordinateurs de bureau
  ou ordinateurs portables de récupération (processeurs double-cœur modestes, 2 à 4 Go
  de mémoire vive, disques durs mécaniques HDD).
- **Options envisagées :**
  1. Polling continu en boucle toutes les 10 secondes et requêtes complètes en RAM.
  2. Isolation multithreadée SQLite, mode WAL, cache RAM borné, et backoff exponentiel — **Retenu**.
- **Décisions techniques retenues :**
  - Exécution SQLite via Isolate d'arrière-plan (`NativeDatabase.createInBackground(file)`).
  - Mode Write-Ahead Logging (`PRAGMA journal_mode = WAL`) et `PRAGMA synchronous = NORMAL`.
  - Limitation du cache SQLite à 64 Mo (`PRAGMA cache_size = -64000`).
  - Suppression de tout polling agressif au profit de vérifications temporisées avec
    backoff exponentiel (15s jusqu'à 10 min en cas d'absence réseau, et 6h en nominal).
  - Mise en cache en mémoire des ancrages de date de démarrage pour éliminer les I/O disque inutiles.
- **Avantages :** Fluidité constante de l'interface graphique Flutter (60 FPS),
  consommation mémoire globale inférieure à 120 Mo, longévité préservée sur disque HDD.

---

## Clôture — Décisions

### État de réalisation (Mise à jour d'audit)

- **ADR-001 (Offline-first / Drift)** : Opérationnel (Schéma v20, 100% autonome).
- **ADR-002 (Clean Architecture)** : Standardisé sur tous les modules avec injection Riverpod.
- **ADR-003 (Riverpod)** : 100% de la gestion d'état et injection de dépendances.
- **ADR-004 (Retrait IA MVP)** : Épuré et respecté.
- **ADR-005 (Licence 3 leviers & Grâce 5j)** : Actif et synchronisé avec Admin Mobile.
- **ADR-006 (Optimisations PC modestes)** : Actif (Isolates, WAL, mémoire bornée).
