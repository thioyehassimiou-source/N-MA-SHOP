# N'Ma Shop (nmashop)

Logiciel **Desktop** de gestion commerciale et de comptabilité **SYSCOHADA**
destiné aux commerçants et petites entreprises de Guinée.
Fonctionne **hors-ligne en priorité** (base de données locale SQLite).

> Le cahier des charges complet est dans `NMASHOP_Cahier_des_charges.docx`.

## Stack technique

| Composant            | Choix                                             |
| -------------------- | ------------------------------------------------- |
| Framework            | Flutter Desktop (Windows prioritaire, Linux/macOS) |
| Base de données      | SQLite via [Drift](https://drift.simonbinder.eu/) |
| Gestion d'état       | Riverpod (`flutter_riverpod`)                      |
| Navigation           | `go_router`                                       |
| Documents PDF        | `pdf` + `printing`                                |


## Démarrer

```bash
flutter pub get
dart run build_runner build        # génère le code Drift (database.g.dart)
flutter run -d linux               # ou -d windows
```

Après toute modification des tables Drift (`lib/core/database/tables/`),
régénérer le code :

```bash
dart run build_runner build
```

Tests et analyse :

```bash
flutter analyze
flutter test
```

## Architecture (feature-first)

```
lib/
├── main.dart                 # bootstrap : ouvre la DB, injecte ProviderScope
├── app.dart                  # MaterialApp.router + thème
├── core/
│   ├── database/
│   │   ├── database.dart      # AppDatabase (Drift) + seed onCreate
│   │   ├── database.g.dart    # généré (ne pas éditer)
│   │   ├── tables/            # définitions des tables
│   │   │   ├── products.dart
│   │   │   ├── customers.dart
│   │   │   ├── sales.dart     # Sales, SaleItems, CreditPayments
│   │   │   ├── stock.dart     # StockMovements
│   │   │   └── accounting.dart# Accounts, JournalEntries, JournalLines
│   │   └── seed/
│   │       └── syscohada_accounts.dart  # plan comptable initial
│   ├── providers/            # databaseProvider (Riverpod)
│   ├── router/               # go_router
│   ├── theme/                # thème sobre, matériel modeste
│   └── format/               # formatage GNF, dates (fr)
└── features/
    ├── dashboard/            # tableau de bord (indicateurs du jour)
    ├── sales/                # ventes & encaissements
    ├── stock/                # produits & stock (fonctionnel)
    ├── receivables/          # créances clients (cahier de crédit)
    ├── accounting/           # comptabilité SYSCOHADA (plan comptable)
    ├── settings/             # configuration boutique / secteur
    ├── shell/                # ossature (NavigationRail)
    └── common/               # widgets partagés
```

La base est stockée dans le dossier support de l'application
(`~/.local/share/com.nmashop.nmashop/nmashop.sqlite` sous Linux).

## État d'avancement

**Fondations posées (scaffold) :**

- ✅ Projet Flutter Desktop (Linux + Windows)
- ✅ Schéma de base de données complet du noyau (produits, clients, ventes,
  lignes de vente, règlements crédit, mouvements de stock, comptabilité)
- ✅ Plan comptable SYSCOHADA (44 comptes) semé au premier lancement
- ✅ App shell avec navigation entre les 7 modules
- ✅ Tableau de bord (indicateurs lus depuis la DB)
- ✅ Module Stock/Produits fonctionnel (liste + création)
- ✅ Module Comptabilité : consultation du plan comptable groupé par classe

**À développer (V1 – MVP) :**

- ⬜ Écran de vente rapide + génération d'écritures comptables automatiques
- ⬜ Mouvements de stock et valorisation CMP (coût moyen pondéré)
- ⬜ Suivi des créances et règlements
- ⬜ Journal, grand livre et balance (édition + export PDF)
- ⬜ Reçus PDF
- ⬜ Modules sectoriels (épicerie, pièces détachées)


> ⚠️ **Conformité :** les écritures et états comptables générés devront être
> validés par un comptable / expert SYSCOHADA avant commercialisation
> (cf. risques du cahier des charges).
