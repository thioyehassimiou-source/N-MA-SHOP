# Feuille de Route Stratégique (Roadmap)

*Calendrier de livraison et jalons de développement.*

Ce document trace l'évolution de N'MaShop de son état de prototype maqueté vers
un logiciel de niveau entreprise. Chaque jalon privilégie la robustesse et la
validation de chaque bloc avant de passer au suivant.

## Chronologie des versions

```mermaid
timeline
    title Livraison N'MaShop
    Version 1.0 (MVP) : Assainissement comptable : Refactoring Stock UI/Data : Espace Comptable simple
    Version 1.1 (Sécurisation) : Chiffrement SQLCipher : Ajustements de stock
    Version 1.2 (ERP local complet) : Gestion Fournisseurs active : Exports SYSCOHADA réels
    Version 2.0 (Multi-postes) : Multi-utilisateurs locaux : Sauvegarde / Sync Cloud
```

---

## Jalon 1 — Version 1.0 (Assainissement et harmonisation comptable)

**Objectif :** nettoyer la dette technique critique et stabiliser le flux
vente/stock pour une comptabilité 100 % fiable.

**Périmètre :**

- **Harmonisation architecture** : migrer le catalogue produits (module `stock`)
  vers Repository + Use Cases (supprimer le couplage widget ↔ Drift).
- **Optimisation Dashboard** : remplacer les chargements complets de tables en RAM
  par des **agrégats SQL**.
- **Fermeture des fuites** : purger lints, warnings, imports inutilisés de l'audit.
- **Caisse & vente opérationnelle** : chaque vente comptant/crédit décrémente
  correctement le stock et écrit une double écriture SYSCOHADA équilibrée.

**Critère de validation :** 100 % des tests unitaires/intégration des Use Cases
passent ; **aucun écart débit/crédit** en base lors des simulations de vente.

---

## Jalon 2 — Version 1.1 (Sécurisation locale et ajustements physiques)

**Objectif :** sécuriser la base au repos et gérer les imprévus (casse, pertes).

**Périmètre :**

- **Chiffrement (SQLCipher)** : rendre `nmashop.sqlite` illisible sans clé.
- **Module d'ajustement de stock** : écarts d'inventaire (constats de perte pour
  casse/vol), avec impact comptable.
- **Sauvegarde USB** : export en un clic d'une sauvegarde complète chiffrée sur
  clé USB (parade aux pannes matérielles).

**Critère de validation :** la base ne s'ouvre plus via un outil SQLite standard ;
la restauration depuis USB fonctionne parfaitement.

---

## Jalon 3 — Version 1.2 (Facturation fournisseurs & exports comptables)

**Objectif :** remplacer les maquettes par une gestion fournisseur complète et de
vrais documents fiscaux.

**Périmètre :**

- **Remplacer le mock Fournisseurs** : connecter `suppliers_screen.dart` aux
  tables d'achats réelles ; enregistrer des factures d'achat à crédit et suivre
  les règlements.
- **Moteur d'export comptable réel** : génération PDF/CSV du Journal, du Grand
  Livre et de la Balance SYSCOHADA (actuellement de simples SnackBars).

**Critère de validation :** les exports CSV s'importent proprement dans un
logiciel de comptabilité tiers (ex. SAGE) sans rejet.

---

## Jalon 4 — Version 2.0 (Multi-utilisateurs et sauvegarde cloud chiffrée)

**Objectif :** travail collaboratif local et sauvegarde à distance.

**Périmètre :**

- **RBAC local** : Propriétaire (accès complet) vs Gérant/Caissier (accès
  restreint à la caisse, sans grand livre, prix d'achat, ni marges).
- **Ouverture/fermeture de caisse** : validation du solde espèces en début et fin
  de journée.
- **Synchronisation cloud hybride** : sauvegarde chiffrée de bout en bout dès
  qu'une connexion est détectée.

**Critère de validation :** le caissier ne peut accéder ni aux réglages ni à la
comptabilité, même en manipulant l'UI.

---

## Clôture — Roadmap

### Incohérences détectées

- **Ordre de livraison** : développer la synchronisation cloud avant d'avoir
  sécurisé le stockage local (SQLCipher) serait une grave erreur. **La sécurité
  locale (V1.1) doit précéder la sécurité réseau (V2.0).**

### Risques

- **Perte de focus MVP** : tentation d'insérer des briques V1.2 (achats
  fournisseurs à crédit) dans la V1.0. Maintenir une **discipline stricte** sur le
  périmètre V1.0.

### Questions ouvertes

- **SemVer strict** pour le desktop ? → Oui : facilite le suivi de compatibilité
  des schémas DB lors des migrations Drift.
- **Migration des données en production** : comment migrer les commerçants déjà en
  prod lors des passages V1.0 → V1.1 (chiffrement) et V1.2 (tables d'achats) ? La
  politique de migration Drift doit être formalisée et testée.

### Décisions à prendre

1. Valider l'ordre de priorité : **assainissement + perf (V1.0)** puis
   **sécurisation (V1.1)**.
2. Toute modification du schéma SQL Drift entraîne **obligatoirement** un test
   unitaire de migration (éviter toute perte de données en production).
