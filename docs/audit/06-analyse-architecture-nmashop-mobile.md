# Spécifications & Analyse d'Architecture : N'MaShop Mobile

*Date d'analyse : 14 Septembre 2026*  
*Cible : Écosystème N'MaShop (Desktop v1.0.0+20 / Admin Mobile v1.0.0 / N'MaShop Mobile V1)*  
*Auteur : Antigravity AI & Direction Technique N'MaShop*

---

## 1. État actuel du projet

L'écosystème **N'MaShop** comprend aujourd'hui deux applications fonctionnelles et stabilisées :

1. **N'MaShop Desktop (`lib/`, `windows/`, `linux/`)** :
   - Application principale client, développée en Flutter / Dart 3.5+.
   - Conçue en **Offline-First strict** avec une base locale Drift SQLite v20 (`nmashop.sqlite`).
   - Couverture fonctionnelle complète : Caisse POS, gestion des stocks et valorisation au Coût Moyen Pondéré (CMP), facturation et tickets PDF, créances clients ("cahier de crédit"), dépenses, fournisseurs et approvisionnements, devis/proformas, gestion d'équipe (vendeurs, commissions), dashboard financier analytique en requêtes SQL agrégées, audit logs et système de licence cryptographique (Ed25519/HMAC-SHA256, liaison HWID, période de grâce de 5 jours, protection anti-recul d'horloge).
   - Qualité industrielle : **0 warning / 0 erreur** sous `flutter analyze lib/`, **76 tests unitaires et d'intégration réussis**.
   - Connexion réseau minimale : un service cloud interroge une base Neon PostgreSQL (`nmashop_activations`) **exclusivement** pour la validation, l'activation et la révocation des licences. **Aucune donnée commerciale (ventes, stocks, caisse, clients) n'est envoyée dans le cloud à ce jour.**

2. **Admin Mobile / Admin Dev (`apps/admin_mobile/`)** :
   - Application mobile Flutter interne, réservée exclusivement au développeur/éditeur.
   - Fonctions : Génération de clés de licence, suivi des HWID, calcul des périodes de grâce (5 jours), envoi des clés par WhatsApp, gestion de la table distante Neon `nmashop_activations`.
   - **Important :** Cette application est un outillage privé dev. Elle ne doit en aucun cas être recyclée en application client commerçant.

3. **N'MaShop Mobile (`apps/customer_mobile` ou `apps/nmashop_mobile`)** :
   - **Inexistant à ce jour.** Aucun code ni structure mobile client n'est encore implémenté.
   - Aucun backend / API de synchronisation des données de gestion commerciale n'est actuellement déployé.

---

## 2. Architecture existante

### 2.1 Découpage logique (Clean Architecture)
L'application Desktop implémente une Clean Architecture en 5 couches étanches documentée dans `docs/audit/05-architecture-technique.md` :
- **Presentation (UI)** : Widgets passifs, écouteurs de StateNotifier/Notifier Riverpod. Aucun calcul financier ni accès SQL direct.
- **Application** : Notifiers Riverpod (ex: `SaleCartController`, `AppSettingsNotifier`).
- **Domain** : Cas d'utilisation (`RecordSaleUseCase`, `RecalculateCmp`), entités immutables et interfaces de repositories (Dart 100% pur, agnostique de Flutter et Drift).
- **Data** : Implémentations concrètes des repositories Drift (`DriftProductRepository`, `DriftSaleRepository`, `DriftDashboardRepository`, `DriftSellerRepository`), mapping de tables et transactions ACID.
- **Infrastructure** : Driver SQLite en Isolate d'arrière-plan (`NativeDatabase.createInBackground`), SharedPreferences, GoRouter.

### 2.2 Base de données locale (Drift SQLite v20)
- Fichier physique : `nmashop.sqlite`.
- Schéma relationnel complet à 20 tables avec clés étrangères activées (`PRAGMA foreign_keys = ON`), mode WAL (`PRAGMA journal_mode = WAL`), cache borné à 64 Mo (`PRAGMA cache_size = -64000`), et cascades de suppression (`ON DELETE CASCADE`).
- Données d'entreprise (nom de la boutique, devise, téléphone, NIF, adresse, logo, domaine d'activité) stockées hors SQL dans `SharedPreferences` via `AppSettingsNotifier`.

### 2.3 Synchronisation actuelle
- Le seul lien réseau existant est `LicenseAdminSyncService` et `LicenseRealtimeService` qui interagissent directement avec Neon PostgreSQL pour la gestion de la table `nmashop_activations` et l'écoute LISTEN/NOTIFY sur `nmashop_license_events`.
- **Il n'existe aucune API REST, aucun service web, ni aucune table cloud pour les opérations commerciales.**

---

## 3. Architecture proposée pour N’MaShop Mobile

### 3.1 Positionnement produit : "Le téléphone du patron"
Le mobile ne reproduit pas le Desktop sur un petit écran. Il obéit à la règle :
$$\text{VOIR} \longrightarrow \text{CONTRÔLER} \longrightarrow \text{\^ETRE ALERTÉ} \longrightarrow \text{DÉCIDER}$$

- Le Desktop est le terminal **opérationnel de saisie et de production** (encaissements, scan code-barres, inventaires, réceptions de marchandises, clôtures de caisse, impression thermique).
- Le Mobile est le terminal **exécutif de surveillance et de décision** pour le propriétaire en déplacement (CA en direct, marge réelle, situation de trésorerie, alertes de rupture, surveillance des vendeurs, relances clients).

### 3.2 Stack technologique recommandée pour le Mobile
- **Framework** : Flutter (permettant la réutilisation des composants visuels, thèmes et formats de `lib/core/format/formatters.dart`).
- **Emplacement dans le monorepo** : `apps/customer_mobile/`.
- **Gestion d'état** : `flutter_riverpod: ^3.3.2` (Notifier / AsyncNotifier).
- **Stockage local / Cache hors-ligne** : Drift SQLite ou Hive / SharedPreferences chiffré pour la persistance des snapshots hors-ligne.
- **Client réseau** : `dio` ou `http` avec interceptors (JWT bearer token, gestion du rafraîchissement transparent, timeout résilient).
- **Sécurité locale** : `flutter_secure_storage` (Android Keystore / iOS Keychain) pour stocker les jetons de session.

---

## 4. Architecture de synchronisation

### 4.1 Analyse comparative des options

| Option | Fonctionnement | Avantages | Inconvénients / Risques | Recommandation |
|---|---|---|---|---|
| **Option A : P2P Réseau Local (Wi-Fi/UDP)** | Desktop et Mobile communiquent directement sur le même Wi-Fi | Coût serveur nul, pas d'infrastructure cloud | **Rédhibitoire** : Ne fonctionne pas si le patron est hors de la boutique en 4G. Problèmes d'isolation Wi-Fi et IP dynamiques. | ❌ Rejetée |
| **Option B : Connexion directe Neon Postgres** | Mobile et Desktop se connectent directement à Neon en SQL | Pas de nouveau serveur d'application à coder | **Faille critique de sécurité** : Connexion SQL directe exposée, pas de multi-tenant étanche, saturation des connexions Neon, impossible de gérer les push notifications. | ❌ Rejetée |
| **Option C : Desktop → API REST Backend → Mobile** | API centrale Cloud avec base PostgreSQL intermédiaire | Sécurité maximale, multi-tenant strict, contrôle d'accès JWT, notifications push faciles, évolutif | Nécessite le déploiement et la maintenance d'un backend léger | 🟢 **Retenue** |
| **Option D : Hybride Push Asynchrone (Queue locale + Snapshots)** | Desktop alimente une table locale `sync_queue` et pousse des snapshots/deltas par batch dès qu'Internet est présent | 100% tolérant aux pannes réseau guinéennes, n'altère pas la réactivité du Desktop, faible consommation de bande passante | Légère complexité de sérialisation sur le Desktop | 🟢 **Composante clé de l'Option C** |

### 4.2 Mécanisme de synchronisation retenu (Architecture Hybride C + D)

1. **Sur N'MaShop Desktop** :
   - Le fonctionnement 100% offline-first reste **intact et prioritaire**.
   - Lorsqu'une transaction est validée en local (vente, dépense, mouvement de caisse), un enregistrement d'événement ou un marquage `needs_sync = true` est créé dans Drift (ou déduit d'un watermark temporel `updated_at`).
   - Un `SyncWorker` d'arrière-plan surveille la connectivité Internet. Dès qu'une connexion stable est disponible, il envoie un batch JSON compact vers l'API Cloud : `POST /api/v1/sync/push`.
   - Si la connexion est coupée pendant 3 jours, Desktop fonctionne normalement. Dès le retour du réseau, tout est rattrapé de manière ordonnée.

2. **Sur le Backend Cloud (API Gateway + Workers)** :
   - Reçoit le batch sous authentification de la machine Desktop (`X-Machine-Token` / `X-License-Key`).
   - Valide l'appartenance au tenant (`shop_id`).
   - Met à jour les tables relationnelles cloud et recalcule les **Snapshots Métier** (KPIs du jour, état des stocks, soldes de trésorerie, performances des vendeurs).
   - Génère les alertes automatiques (ruptures, anomalies de caisse, créances échues).

3. **Sur N'MaShop Mobile** :
   - Le téléphone interroge l'API : `GET /api/v1/mobile/dashboard`, etc.
   - Les réponses JSON sont immédiatement sauvegardées en cache local persistant.
   - L'application affiche de manière explicite et permanente :
     > « Synchronisé il y a 4 min » ou « Données hors-ligne (Dernière sync : Aujourd'hui à 11:30) ».
   - Un geste "Pull-to-refresh" permet de forcer l'interrogation de l'API.

---

## 5. Modèle de données (Data Model)

### 5.1 Cartographie Desktop existante vs Données Mobile

| Entité Desktop | Données locales disponibles | Données nécessaires Mobile | Mode de transfert vers Mobile | Données sensibles à protéger |
|---|---|---|---|---|
| **Entreprise / Shop** | `AppSettings` (nom, devise, nif, phone, logo) | Nom, logo, téléphone, devise, statut licence | Snapshot lors du jumelage | Clés de licence privées, HWID |
| **Ventes (`sales`)** | Id, ref, client, vendeur, date, total, payé, mode, isCancelled | CA du jour, nb ventes, panier moyen, historique filtrable, ventilation par paiement | Agrégats journaliers + Liste compacte des dernières ventes | Marge brute unitaire non visible des caissiers |
| **Lignes Vente (`sale_items`)** | Id, label, quantité, prix unit, CMP unitaire, total ligne | Marge brute par produit, top ventes, produits rentables vs faibles marges | Calculé côté serveur / Agrégé | CMP brut masqué sur les tickets |
| **Stock (`products`)** | Id, nom, ref, unit, prix achat, prix vente, quantité, seuil, CMP, barcode | Alertes rupture, stock faible, produits dormants, rotation, réapprovisionnement conseillé | Liste filtrée des alertes + Catalogue synthétique | Prix d'achat fournisseur |
| **Fournisseurs & Achats** | `suppliers`, `purchases`, `purchase_items` | Dernier prix d'achat, fournisseur principal du produit à commander | Associé à la fiche produit lors de l'alerte réapprovisionnement | Conditions de crédit fournisseur |
| **Caisse & Dépenses** | `cash_movements`, `expenses` | Total espèces, solde théorique, cumul dépenses, ventilation catégories | Agrégats de trésorerie | Justificatifs confidentiels |
| **Créances (`customers`, `sales`)** | Total vente - payé, date dernière vente, paiements partiels | Total créances, liste débiteurs avec montant et ancienneté (jours) | Liste détaillée des soldes clients ouverts | Coordonnées privées clients |
| **Équipe (`users`, `sales`)** | Vendeurs, taux commission, ventes associées | CA par vendeur, commissions calculées, ventes comptant/crédit, remises | Tableau de bord de performance équipe | Hash des mots de passe (`passwordHash`, `passwordSalt`) |
| **Audit & Sécurité** | `audit_logs` (annulations, suppressions, modifs prix) | Détection d'anomalies (annulations répétées, fortes remises) | Flux d'événements critiques | Données de session |

### 5.2 Informations Manquantes identifiées dans le code Desktop

> **INFORMATION MANQUANTE N°1 — Distinction Orange Money vs MTN MoMo**  
> *Constat dans le code :* Dans `lib/core/domain/payment_method.dart`, l'énumération est définie ainsi :  
> `enum PaymentMethod { cash, mobileMoney, credit, bank }`  
> Il n'existe pas d'entrée distincte pour Orange Money et MTN MoMo dans la base locale SQLite. Les règlements par téléphone sont tous regroupés sous `mobileMoney` (ou distingués informellement dans la colonne texte `note`).  
> *Proposition de résolution :*  
> 1. Conserver l'intEnum Drift existant sans casser la compatibilité v20.  
> 2. Soit faire évoluer l'énumération via une migration Drift v21 en ajoutant `orangeMoney` et `mtnMoney` à la fin de l'enum (sans modifier les index 0..3 existants) ;  
> 3. Soit stocker l'opérateur dans un champ dédié de la table `sales` et `cash_movements`.

> **INFORMATION MANQUANTE N°2 — Date d'échéance formelle des créances (`dueDate`)**  
> *Constat dans le code :* Dans `lib/core/database/tables/sales.dart`, il n'y a pas de champ `dueDate`. L'ancienneté de la dette dans `CreditSummary` est calculée à partir de `lastSaleDate` (date de la facture). Le concept de "Nombre de jours de retard" par rapport à une date d'échéance promise n'est pas modélisé.  
> *Proposition de résolution :*  
> Pour la V1 : Définir le retard comme le nombre de jours écoulés depuis la vente non soldée (ex: `date_vente + 30 jours` par défaut), ou ajouter une colonne `due_date` optionnelle dans une prochaine migration.

> **INFORMATION MANQUANTE N°3 — Modélisation formelle des Écarts de Caisse**  
> *Constat dans le code :* `AuditActionType.cashClosed` existe dans `audit_logs.dart`, mais il n'existe pas de table `cash_sessions` contenant `expected_cash`, `actual_cash` et `discrepancy`.  
> *Proposition de résolution :*  
> Le signalement d'un "écart de caisse" sur mobile doit être déclenché dès qu'un mouvement d'ajustement de caisse négatif/positif est saisi sur Desktop, ou dès qu'un log d'audit de type `cashClosed` signale une divergence dans son champ `details`.

---

## 6. API nécessaires (Spécification des Endpoints Backend)

Le backend exposera une API RESTful sécurisée sous HTTPS (`/api/v1`).

### 6.1 Authentification & Appareils
- `POST /api/v1/auth/login` : Authentification du propriétaire (téléphone + mot de passe).
- `POST /api/v1/auth/refresh` : Rafraîchissement du JWT token via Refresh Token.
- `POST /api/v1/auth/pair-device` : Jumelage sécurisé via scan du QR code affiché sur le Desktop.
- `POST /api/v1/auth/logout` : Révocation du token et de l'appareil.

### 6.2 Synchronisation Ingestion (Desktop → Backend)
- `POST /api/v1/sync/push` : Réception d'un lot de données transactionnelles depuis Desktop :
  ```json
  {
    "machineId": "HWID-XXXX-YYYY",
    "licenseKey": "NMASHOP-2026-...",
    "shopId": "uuid-shop-001",
    "timestamp": "2026-09-14T09:30:00Z",
    "sales": [ ... ],
    "stockDeltas": [ ... ],
    "cashMovements": [ ... ],
    "expenses": [ ... ],
    "auditEvents": [ ... ]
  }
  ```
- `GET /api/v1/sync/status` : Contrôle de l'état de la synchronisation.

### 6.3 Consultation Mobile (Backend → Mobile)
- `GET /api/v1/mobile/dashboard` :
  - Métriques d'aujourd'hui : CA, bénéfice estimé, nb ventes, panier moyen.
  - Ventilation argent : Espèces, Mobile Money (Orange/MTN), créances du jour.
  - Alertes prioritaires (ruptures imminentes, écarts de caisse, créances en souffrance).
- `GET /api/v1/mobile/sales?period=today|7d|30d|custom&start=&end=` :
  - Historique synthétique, courbe d'évolution journalière, ventilation par mode de paiement, top 10 articles vendus.
- `GET /api/v1/mobile/profitability` :
  - CA global, Coût total des marchandises vendues (CMP), Marge brute, Taux de marge.
  - Top 5 des produits les plus rentables.
  - Top 5 des produits à faible marge (< 5%).
  - Produits à fort volume mais faible contribution au bénéfice.
- `GET /api/v1/mobile/treasury` :
  - Solde espèces théorique, Mobile Money, total dépenses du mois, ventilation par catégorie de dépense.
- `GET /api/v1/mobile/stock` :
  - Articles à 0 (rupture), articles $\le$ seuil d'alerte, produits dormants (> 30j sans vente).
  - Suggestions déterministes de réapprovisionnement (Vente moyenne journalière $\times$ délai de réappro - stock actuel).
- `GET /api/v1/mobile/receivables` :
  - Total des dettes en cours, nombre de débiteurs, liste ordonnée par ancienneté avec coordonnées du client.
- `GET /api/v1/mobile/team` :
  - Performances des vendeurs sur la période (CA, commissions acquises, nombre de ventes, annulations).
- `GET /api/v1/mobile/alerts` :
  - Flux des alertes non acquittées (Stock, Finance, Équipe, Anomalies).
- `POST /api/v1/mobile/alerts/:id/ack` : Acquittement d'une alerte par le patron.
- `GET /api/v1/mobile/profile` : Informations sur la boutique et état de la licence.

---

## 7. Authentification

### 7.1 Processus de Jumelage (Device Pairing)
Pour éviter aux commerçants de saisir des identifiants serveurs complexes :
1. Sur Desktop, l'administrateur clique sur **"Connecter mon smartphone"** dans les paramètres.
2. Desktop génère un QR code temporaire contenant :
   - L'URL de l'API centrale
   - Le `tenantId` / `shopId`
   - Un jeton d'appairage cryptographique éphémère (validité 10 minutes)
3. Sur le Mobile, le patron installe N'MaShop Mobile et scanne le QR code.
4. L'application mobile demande alors au patron de définir son code PIN ou mot de passe patron.
5. Le serveur valide le jumelage et émet :
   - Un `AccessToken` (durée de vie : 15 minutes)
   - Un `RefreshToken` (durée de vie : 90 jours, stocké dans `FlutterSecureStorage`)

### 7.2 Sécurité de la session
- Vérification biométrique locale (Empreinte digitale / Face ID) optionnelle à chaque ouverture de l'application sans ressaisie du mot de passe.
- Possibilité pour le commerçant de révoquer un téléphone perdu directement depuis N'MaShop Desktop ou depuis le portail d'administration.

---

## 8. Sécurité

1. **Isolation Multi-Tenant absolue** : Chaque requête API est filtrée par un middleware validant que les données accédées appartiennent strictement au `shop_id` extrait du JWT.
2. **Chiffrement de bout en bout en transit** : HTTPS / TLS 1.3 obligatoire, avec Certificate Pinning optionnel sur l'application mobile.
3. **Stockage sécurisé des secrets** :
   - Aucun token ni mot de passe en clair dans `SharedPreferences`.
   - Utilisation de `FlutterSecureStorage` (Keystore matériel Android sous TEE/Knox, Keychain Apple avec `kSecAttrAccessibleAfterFirstUnlock`).
4. **Protection contre les attaques par force brute** : Rate-limiting sur l'API (maximum 5 tentatives de connexion par minute par IP).
5. **Principe du moindre privilège** : L'API mobile ne donne accès qu'aux endpoints de consultation et de validation de décisions. Elle ne permet pas d'effacer la base de données ou de modifier les historiques comptables du Desktop.

---

## 9. Liste complète des écrans

```
[Splash / Contrôle Session]
       │
       ├── Non connecté ──► [Écran Jumelage / Scan QR Code & PIN]
       │
       └── Connecté ─────► [Shell Principal avec Navigation 5 Onglets]
                                 │
         ┌───────────────────────┼────────────────────────┬──────────────────────┐
         ▼                       ▼                        ▼                      ▼
  [1. Accueil / Dashboard]   [2. Ventes & Activité]   [3. Trésorerie]       [4. Stock]       [5. Plus / Menu]
  - KPIs du jour             - Historique ventes      - Espèces             - Ruptures       - Rentabilité
  - Argent en caisse         - Filtres temporels      - Mobile Money        - Stock faible   - Créances clients
  - Alertes critiques        - Graphique CA           - Dépenses            - Dormants       - Suivi Équipe
  - Raccourcis clés          - Répartition paiement   - Solde théorique     - Réappro conseil- Alertes & Fraude
                             - Top 10 articles                              - Fiche produit  - Profil Boutique
```

### Détail des Écrans :
1. **Écran 1 — Dashboard (Accueil)** : Vue ultra-synthétique à lecture en 5 secondes (CA du jour, bénéfice estimé, espèces/MoMo, 3 alertes urgentes).
2. **Écran 2 — Activité & Ventes** : Filtres (Aujourd'hui, 7 jours, 30 jours, Mois), CA vs période précédente, graphique de tendance, ventilation des règlements, top ventes.
3. **Écran 3 — Trésorerie** : Vue consolidée de l'argent (Espèces physiques, Orange Money, MTN MoMo, créances en attente, dépenses payées, solde net).
4. **Écran 4 — Stock & Vigilance** : Ruptures (stock = 0), alertes de stock faible, produits sans rotation depuis 30 jours, suggestions de commande avec calcul déterministe.
5. **Écran 5 — Rentabilité & Marges (Sous-écran "Plus")** : Marge brute globale, taux de marge %, top 5 articles à forte marge, top 5 articles à marge critique, produits à fort volume sans profit.
6. **Écran 6 — Clients & Créances (Sous-écran "Plus")** : Total dû, nombre de débiteurs, liste classée par ancienneté avec bouton direct "Relancer par WhatsApp".
7. **Écran 7 — Équipe & Collaborateurs (Sous-écran "Plus")** : Liste des vendeurs, nombre de tickets, CA généré, commissions acquises, suivi des annulations de vente.
8. **Écran 8 — Centre d'Alertes & Contrôle Anti-Fraude (Sous-écran "Plus")** : Liste chronologique des alertes (anomalies de caisse, remises inhabituelles, annulations de vente en cascade).
9. **Écran 9 — Profil & Paramètres (Sous-écran "Plus")** : Informations de la boutique, état de la licence, heure de dernière synchronisation, sécurité biométrique, déconnexion.

---

## 10. Parcours utilisateur (User Journeys)

### Parcours 1 : Premier jumelage par le commerçant
1. Le patron installe N'MaShop Mobile sur son smartphone Android/iOS.
2. Au lancement, l'application affiche un écran épuré : "Liez votre boutique".
3. Le patron ouvre son PC N'MaShop Desktop $\rightarrow$ clique sur l'icône smartphone $\rightarrow$ un QR code s'affiche.
4. Le patron clique sur "Scanner le QR Code" sur son téléphone et vise l'écran du PC.
5. Le téléphone est reconnu immédiatement ("Boutique Diallo & Frères reconnue").
6. Le patron choisit un code PIN à 4 chiffres $\rightarrow$ Le dashboard se charge avec les données synchronisées.

### Parcours 2 : Contrôle matinal rapide (5 secondes)
1. Le patron est à la maison ou sur la route. Il ouvre l'application avec son empreinte digitale.
2. Il voit immédiatement :
   - CA d'hier et comparaison avec la semaine passée.
   - Si la caisse a bien été ouverte ce matin.
   - Les éventuelles alertes rouges : "2 produits en rupture".
3. Il referme l'application en étant rassuré.

### Parcours 3 : Contrôle de fin de journée & Surveillance anti-fraude
1. À 20h, le patron ouvre l'onglet **Trésorerie**.
2. Il compare le montant en espèces théorique avec ce que le gérant lui annonce au téléphone.
3. Il bascule sur l'onglet **Équipe** : il constate que le vendeur Mamadou a réalisé 28 ventes, mais remarque dans le centre d'alertes : "3 ventes annulées consécutives par Mamadou entre 17h10 et 17h18".
4. Il peut appeler immédiatement le gérant pour clarifier l'anomalie avec les références exactes des tickets.

### Parcours 4 : Recouvrement des créances en 1 clic
1. Le patron consulte l'écran **Créances**.
2. Il voit le client "Bah Alpha" avec un impayé de 650 000 GNF depuis 24 jours.
3. Il clique sur le bouton vert **"Relancer"**.
4. L'application mobile ouvre directement WhatsApp avec un message pré-rempli, courtois et personnalisé :
   > « Bonjour M. Bah, sauf erreur de notre part, votre compte chez Boutique Diallo & Frères présente un solde restant de 650 000 GNF. Merci de nous contacter pour convenir du règlement. Belle journée à vous. »

---

## 11. MVP V1 (Périmètre strict de la Première Version)

Le MVP se concentre sur les fonctionnalités apportant 90% de la valeur perçue par le patron :

1. **Architecture de synchronisation & Ingestion API** :
   - Service de push périodique sur Desktop (background worker).
   - Backend REST léger assurant l'ingestion, le calcul des agrégats et l'isolation multi-tenant.
2. **Authentification & Jumelage 1-clic par QR Code**.
3. **Écran 1 — Dashboard (Accueil)** :
   - CA du jour, marge estimée (calculée avec le CMP Desktop), nombre de transactions, panier moyen.
   - Total encaissé : Espèces vs Mobile Money.
   - Reste à recouvrer (crédits).
   - Cartouche de statut de synchronisation ("Dernière mise à jour : il y a 3 min").
4. **Écran 2 — Ventes & Activité** :
   - Ventes du jour et des 7 derniers jours.
   - Graphique épuré du CA de la semaine.
   - Ventilation des encaissements par moyen de paiement.
   - Top 5 des produits les plus vendus.
5. **Écran 3 — Trésorerie** :
   - Répartition de l'argent liquide et Mobile Money.
   - Cumul des dépenses enregistrées.
6. **Écran 4 — Stock & Alertes Ruptures** :
   - Liste des produits en rupture critique (stock = 0).
   - Liste des produits sous le seuil d'alerte.
7. **Cache hors-ligne de consultation** :
   - Toutes les dernières données restent consultables sans réseau.

---

## 12. Fonctionnalités P1 (Seconde Vague)

1. **Rentabilité fine** : Marge brute détaillée par famille de produit, identification des produits à fort volume mais marge dérisoire.
2. **Créances clients complètes** : Liste de tous les débiteurs, calcul du nombre de jours d'ancienneté, historique des règlements partiels.
3. **Module Équipe** : Suivi des ventes par vendeur, calcul des commissions selon les taux paramétrés sur Desktop, décompte des annulations.
4. **Centre d'alertes & Détection déterministe d'anomalies** : Règles de surveillance (remises supérieures à 15%, annulations consécutives, écarts de caisse).
5. **Suggestions déterministes de réapprovisionnement** (Ventes moyennes constatées sur 14 jours vs stock restant).

---

## 13. Fonctionnalités P2 (Troisième Vague)

1. **Génération de message de relance WhatsApp 1-clic**.
2. **Support multi-boutiques** (pour les commerçants possédant 2 ou 3 points de vente avec bascule instantanée sur le mobile).
3. **Rapports PDF exécutifs** (génération d'un bilan hebdomadaire ou mensuel partageable par WhatsApp/Email).
4. **Notifications Push natives (FCM)** en cas d'alerte critique (ex: rupture d'un produit phare ou tentative d'accès suspecte).

---

## 14. Ce qui reste exclusivement sur Desktop

Ces opérations ne doivent **jamais** être portées sur le mobile client :
- La saisie des ventes en caisse (POS, écran tactile caisse, lecteur de code-barres).
- L'impression des tickets sur imprimante thermique 58mm/80mm (ESC/POS).
- L'enregistrement des achats et réceptions de commandes fournisseurs.
- La création, modification ou suppression d'articles dans le catalogue.
- L'ajustement manuel des stocks et inventaires physiques.
- La saisie manuelle des dépenses quotidiennes.
- La clôture de caisse quotidienne (comptage physique du tiroir-caisse).
- La gestion des utilisateurs locaux (création de comptes caissiers, modification de rôles).
- La sauvegarde locale de la base SQLite (`.sqlite`) et sa restauration.
- La gestion cryptographique de la licence matérielle (HWID binding).

---

## 15. Ce qui reste exclusivement dans Admin Dev (`apps/admin_mobile`)

L'application existante du développeur conserve strictement son rôle :
- Génération des clés de licence Ed25519/HMAC pour les clients.
- Révocation et renouvellement des licences.
- Visualisation de la liste des boutiques clientes de l'éditeur.
- Contrôle des HWID et des dates de fin de validité.
- Gestion du délai de grâce de 5 jours (`offlineGracePeriodDays`).
- Support technique et assistance directe au numéro officiel **+224 624 19 30 69**.

---

## 16. Risques techniques & Mesures de mitigation

1. **Connectivité intermittente en Guinée (Coupures 3G/4G, pannes d'électricité)** :
   - *Impact :* Le Desktop peut ne pas pouvoir synchroniser pendant plusieurs heures ou jours.
   - *Mitigation :* Architecture **tolérante au décalage**. Le Desktop stocke les deltas dans une table locale `sync_queue`. Le Mobile affiche toujours clairement l'âge des données consultées. Pas de promesse de "temps réel absolu" mensongère.
2. **Conflits d'écriture et de concurrence** :
   - *Impact :* Risque d'écrasement si le mobile et le PC écrivent en même temps.
   - *Mitigation :* En V1 et P1, le **Mobile est en lecture seule** (aucun conflit possible). Seul le Desktop est producteur de données d'exploitation.
3. **Désynchronisation d'horloge** :
   - *Impact :* L'horloge Windows locale peut être faussée.
   - *Mitigation :* N'MaShop Desktop possède déjà un système anti-tampering (`anti-clock-tampering`). Le backend impose son propre horodatage UTC serveur lors de l'ingestion des paquets.
4. **Consommation de données mobiles & Coût de la bande passante** :
   - *Impact :* Les forfaits data sont chers en Guinée.
   - *Mitigation :* Payloads JSON compressés (Gzip), pas d'images lourdes synchronisées, uniquement des données numériques agrégées.

---

## 17. Risques business & Recommandations de packaging

1. **Refus de payer un surcoût pour le mobile** :
   - Si le commerçant perçoit le mobile comme un gadget, il refusera l'abonnement supérieur.
   - *Recommandation de packaging commercial :*
     - **Formule "N'MaShop Solo"** : Desktop seul (licence à vie ou annuelle classique).
     - **Formule "N'MaShop Sérénité / Patron"** : Desktop + Accès Mobile Illimité + Sauvegarde Cloud automatique. La valeur vendue n'est pas "une app mobile", mais **la tranquillité d'esprit de surveiller sa boutique à distance**.
2. **Perception de complexité** :
   - Si l'application mobile est encombrée de tableaux comptables, le commerçant ne l'ouvrira pas.
   - *Recommandation :* Typographie grande et contrastée (Inter), chiffres en GNF clairement mis en avant, zéro jargon technique ("Bénéfice estimé" plutôt que "Marge d'exploitation EBE").

---

## 18. Estimation de complexité par module

| Module | Composants impliqués | Complexité | Effort estimé |
|---|---|---|---|
| **1. Moteur de synchronisation Desktop (Push)** | Drift SQLite (table queue / deltas), Riverpod, Worker réseau résilient | Moyenne | 4 jours |
| **2. Backend API Cloud & Ingestion** | NestJS / Dart Frog, PostgreSQL multi-tenant, validation JWT & Machine Tokens | Moyenne-Haute | 5 jours |
| **3. Socle N'MaShop Mobile (`apps/customer_mobile`)** | Clean architecture Flutter, Riverpod, GoRouter, SecureStorage, Thème officiel | Moyenne | 3 jours |
| **4. Module Auth & Jumelage QR Code** | Générateur QR sur Desktop, Scanner caméra sur Mobile, échange de clés | Faible-Moyenne | 2 jours |
| **5. Écran Dashboard (Accueil Mobile)** | Widgets KPI, cartes argent, état de synchronisation, pull-to-refresh | Faible | 2 jours |
| **6. Écran Activité & Ventes Mobile** | Graphique fl_chart, filtres temporels, listes optimisées | Moyenne | 3 jours |
| **7. Écran Trésorerie Mobile** | Cartes de répartition des flux, indicateurs solde | Faible | 2 jours |
| **8. Écran Stock & Alertes Mobile** | Liste ruptures, seuils d'alerte, indicateurs de rotation | Faible-Moyenne | 2 jours |
| **9. Écran Rentabilité & Marges (P1)** | Calculs de marge basés sur le CMP, top/flop produits | Moyenne | 2 jours |
| **10. Écran Créances & Relances (P1/P2)** | Suivi ancienneté, détail client, intégration WhatsApp | Faible | 2 jours |
| **11. Écran Équipe & Surveillance (P1)** | Analyse des ventes par vendeur, calcul des commissions | Moyenne | 2 jours |
| **12. Centre d'Alertes & Fraude (P1)** | Moteur de règles déterministes, flux des anomalies | Moyenne | 3 jours |

---

## 19. Ordre d'implémentation logique

Le développement doit suivre une progression séquentielle stricte où chaque étape s'appuie sur une fondation validée :

```
Phase 1 : Contrat d'API & Backend Ingestion
   │
   ▼
Phase 2 : Export / Push Worker côté N'MaShop Desktop (sans régression offline)
   │
   ▼
Phase 3 : Création de l'application Flutter N'MaShop Mobile (`apps/customer_mobile`)
   │
   ▼
Phase 4 : Authentification & Jumelage sécurisé par QR Code
   │
   ▼
Phase 5 : Écran 1 — Dashboard Mobile (Accueil & Chiffres clés)
   │
   ▼
Phase 6 : Écran 2 — Activité & Ventes (Filtres & Graphiques)
   │
   ▼
Phase 7 : Écran 3 — Trésorerie (Espèces, Mobile Money, Dépenses)
   │
   ▼
Phase 8 : Écran 4 — Stock (Ruptures & Alertes)
   │
   ▼
Phase 9 : Validation MVP V1 & Tests End-to-End
   │
   ▼
Phase 10 : Modules P1 (Rentabilité, Créances, Équipe, Anomalies)
```

---

## 20. Stratégie de tests

1. **Tests unitaires (Backend & Mobile)** :
   - Validation des calculs de rentabilité et de CMP (garantir la parité exacte avec le calcul Drift SQL du Desktop).
   - Validation des agrégats de ventes et de trésorerie.
   - Tests de sérialisation/désérialisation JSON des payloads de synchronisation.
2. **Tests d'intégration Desktop $\rightarrow$ API** :
   - Test du `SyncWorker` en simulation de coupure réseau (mode hors-ligne $\rightarrow$ cumul dans la file $\rightarrow$ reconnexion $\rightarrow$ vidage de la file sans doublon).
   - Test de non-régression sur le Desktop : aucune écriture sur le thread d'UI, maintien rigoureux des 60 FPS en caisse.
3. **Tests d'authentification et de sécurité multi-tenant** :
   - Vérification qu'une boutique B ne peut sous aucun prétexte lire les données de la boutique A via l'API.
   - Test d'expiration et de rafraîchissement des tokens JWT.
4. **Tests d'interface mobile (Golden & Widget tests)** :
   - Rendu fidèle sur différentes tailles d'écrans (smartphones d'entrée de gamme Android à petits écrans vs grands écrans).
   - Lisibilité maximale en extérieur (fort contraste, typographie Inter, conformité à la palette officielle N'MaShop).
5. **Critères de validation avant chaque livraison** :
   - `flutter analyze` 100% vierge (0 avertissement, 0 erreur).
   - 100% des tests automatisés au vert.

---

## 21. Architecture finale recommandée (Diagramme ASCII)

```
┌───────────────────────────────────────────────────────────────────────────┐
│                           BOUTIQUE COMMERÇANTE                            │
│                                                                           │
│   ┌───────────────────────────────────────────────────────────────────┐   │
│   │                     N'MASHOP DESKTOP (PC)                         │   │
│   │                                                                   │   │
│   │   [Caisse POS]   [Stock & CMP]   [Achats]   [Dépenses]   [Audit]  │   │
│   │        │               │             │           │          │     │   │
│   │        ▼               ▼             ▼           ▼          ▼     │   │
│   │   ┌───────────────────────────────────────────────────────────┐   │   │
│   │   │             Base Locale Drift SQLite v20                  │   │   │
│   │   │             (nmashop.sqlite — 100% Offline)               │   │   │
│   │   └─────────────────────────────┬─────────────────────────────┘   │   │
│   │                                 │                                 │   │
│   │                  Watermark / Queue de Synchro                     │   │   │
│   │                                 │                                 │   │
│   │                   ┌─────────────▼───────────────┐                 │   │
│   │                   │   Desktop Sync Worker       │                 │   │
│   │                   │ (Async, Backoff Exponentiel)│                 │   │
│   │                   └─────────────┬───────────────┘                 │   │
│   └─────────────────────────────────┼─────────────────────────────────┘   │
└─────────────────────────────────────┼─────────────────────────────────────┘
                                      │
                   HTTPS / TLS 1.3    │ [Push Snapshots & Deltas]
                   (Quand Internet    │ Machine-Token Authentifié
                    est disponible)   ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                           CLOUD N'MASHOP (API)                            │
│                                                                           │
│   ┌───────────────────────────────────────────────────────────────────┐   │
│   │                        API GATEWAY REST                           │   │
│   │       - Rate Limiting                                             │   │
│   │       - Auth & Multi-Tenant Middleware (Shop Isolation)           │   │
│   └──────────────────┬────────────────────────────▲───────────────────┘   │
│                      │ Ingestion                  │ Lecture               │
│                      ▼                            │ Snapshots             │
│   ┌───────────────────────────────────┐           │                       │
│   │     POSTGRESQL MULTI-TENANT       │           │                       │
│   │  (Tables Tenants, Sync Snapshots, ├───────────┘                       │
│   │   Aggrégats Journaliers, Alertes) │                                   │
│   └──────────────────┬────────────────┘                                   │
│                      │                                                    │
│                      ▼                                                    │
│   ┌───────────────────────────────────┐                                   │
│   │     Moteur d'Alertes Métier       │                                   │
│   │  (Ruptures, Écarts, Anomalies)    │                                   │
│   └───────────────────────────────────┘                                   │
└───────────────────────────────────────▲───────────────────────────────────┘
                                        │
                     HTTPS / TLS 1.3    │ [GET /dashboard, /sales, /stock...]
                     (JWT Bearer Token) │ Lecture rapide & Pull-to-refresh
                                        │
┌───────────────────────────────────────┴───────────────────────────────────┐
│                      N'MASHOP MOBILE ("Le Patron")                        │
│                                                                           │
│   ┌───────────────────────────────────────────────────────────────────┐   │
│   │     UI FLUTTER MOBILE (apps/customer_mobile)                      │   │
│   │                                                                   │   │
│   │   [Accueil / CA]   [Ventes]   [Trésorerie]   [Stock]   [Alertes]  │   │
│   │         │             │            │            │          │      │   │
│   │         ▼             ▼            ▼            ▼          ▼      │   │
│   │   ┌───────────────────────────────────────────────────────────┐   │   │
│   │   │         Riverpod Providers & Application Controllers      │   │   │
│   │   └─────────────────────────────┬─────────────────────────────┘   │   │
│   │                                 │                                 │   │
│   │   ┌─────────────────────────────▼─────────────────────────────┐   │   │
│   │   │       Cache Local Sécurisé (Offline Read-Only)            │   │   │
│   │   │     « Synchronisé il y a 3 min » / Accès instantané       │   │   │
│   │   └───────────────────────────────────────────────────────────┘   │   │
│   └───────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────────┘
                                      ▲
                                      │ Consultation externe
                                      │
┌─────────────────────────────────────┴─────────────────────────────────────┐
│             ADMIN MOBILE / DEV (apps/admin_mobile)                        │
│             - Outil privé Développeur / Éditeur uniquement                │
│             - Gestion des licences Ed25519, HWID, Période de grâce        │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## 22. Plan de développement détaillé (Tâches unitaires)

### Module 1 : Contrat de Synchronisation & Préparation Backend
- [ ] **Tâche 1.1** : Définir le contrat d'interface JSON pour l'export Desktop (DTOs `SyncPayload`, `SaleSyncDto`, `StockSyncDto`, `CashSyncDto`).
- [ ] **Tâche 1.2** : Mettre en place le projet backend d'API avec base PostgreSQL, isolation multi-tenant et schéma d'ingestion.
- [ ] **Tâche 1.3** : Implémenter l'endpoint `POST /api/v1/sync/push` avec validation de la machine et calcul automatique des agrégats journaliers.
- [ ] **Tâche 1.4** : Écrire les tests unitaires et d'intégration de l'endpoint d'ingestion.

### Module 2 : Moteur d'Export et Synchronisation sur N'MaShop Desktop
- [ ] **Tâche 2.1** : Créer le service de tracking des modifications sur Desktop (watermark / table `sync_watermarks` sans impacter le schéma commercial v20).
- [ ] **Tâche 2.2** : Implémenter le `DesktopSyncWorker` avec détection de connectivité réseau et mécanisme de backoff exponentiel.
- [ ] **Tâche 2.3** : Ajouter dans les Paramètres Desktop l'indicateur d'état du service de synchronisation ("En ligne / Synchronisé" ou "Hors-ligne").
- [ ] **Tâche 2.4** : Créer l'écran de dialogue Desktop "Connecter mon smartphone" affichant le QR code de jumelage chiffré.
- [ ] **Tâche 2.5** : Exécuter la suite de tests Desktop (`flutter test`) et vérifier que les 76 tests restent à 100% au vert.

### Module 3 : Initialisation du Projet N'MaShop Mobile (`apps/customer_mobile`)
- [ ] **Tâche 3.1** : Initialiser l'application Flutter dans `apps/customer_mobile` avec configuration Android / iOS minimale.
- [ ] **Tâche 3.2** : Configurer les dépendances (`flutter_riverpod`, `dio`/`http`, `flutter_secure_storage`, `intl`, `fl_chart`, `mobile_scanner`).
- [ ] **Tâche 3.3** : Intégrer la charte graphique officielle N'MaShop (couleurs `AppColors`, police variable Inter empaquetée en local, `formatters.dart` pour le GNF).
- [ ] **Tâche 3.4** : Mettre en place le routeur `go_router` avec redirection dynamique (garde d'authentification).

### Module 4 : Authentification, Jumelage & Cache Mobile
- [ ] **Tâche 4.1** : Implémenter l'écran de jumelage avec scanner QR Code (caméra).
- [ ] **Tâche 4.2** : Implémenter l'écran de saisie / confirmation du code PIN patron.
- [ ] **Tâche 4.3** : Mettre en place le stockage sécurisé du Refresh Token et l'intercepteur de rafraîchissement transparent.
- [ ] **Tâche 4.4** : Implémenter la couche de cache local pour permettre l'ouverture instantanée de l'application hors-ligne.

### Module 5 : Écran 1 — Dashboard / Accueil (MVP)
- [ ] **Tâche 5.1** : Créer les modèles et le repository distant pour les indicateurs du tableau de bord.
- [ ] **Tâche 5.2** : Implémenter la carte d'en-tête "Bonjour 👋" avec l'indicateur d'âge de synchronisation.
- [ ] **Tâche 5.3** : Implémenter la section "Aujourd'hui" (CA, Bénéfice estimé, Nombre de ventes, Panier moyen).
- [ ] **Tâche 5.4** : Implémenter la section "Argent" (Espèces, Orange Money, MTN MoMo, Crédits en cours).
- [ ] **Tâche 5.5** : Implémenter la section "Attention" (Badges d'alerte ruptures et retards de créances).
- [ ] **Tâche 5.6** : Intégrer le "Pull-to-refresh" pour forcer la synchronisation.

### Module 6 : Écran 2 — Activité & Ventes (MVP)
- [ ] **Tâche 6.1** : Créer le contrôleur Riverpod avec sélecteur de période (Aujourd'hui, 7 jours, 30 jours, Mois en cours).
- [ ] **Tâche 6.2** : Implémenter le graphique épuré d'évolution du CA (fl_chart).
- [ ] **Tâche 6.3** : Implémenter la jauge de répartition par moyen de paiement.
- [ ] **Tâche 6.4** : Implémenter la liste des articles les plus vendus sur la période.

### Module 7 : Écran 3 — Trésorerie (MVP)
- [ ] **Tâche 7.1** : Créer l'écran de synthèse des disponibilités financières.
- [ ] **Tâche 7.2** : Afficher séparément le solde théorique de caisse (espèces), les soldes Mobile Money, les créances et les décaissements.
- [ ] **Tâche 7.3** : Afficher la liste des dernières dépenses opérationnelles avec libellé et catégorie.

### Module 8 : Écran 4 — Stock & Ruptures (MVP)
- [ ] **Tâche 8.1** : Implémenter l'onglet "Ruptures" (produits à stock = 0).
- [ ] **Tâche 8.2** : Implémenter l'onglet "Stock faible" (produits sous le seuil d'alerte).
- [ ] **Tâche 8.3** : Afficher la fiche synthétique du produit (nom, stock actuel, seuil, dernier prix d'achat, fournisseur principal).

### Module 9 : Modules P1 (Rentabilité, Créances, Équipe, Anomalies)
- [ ] **Tâche 9.1** : Développer l'écran Rentabilité (Marge brute, Taux de marge, Top rentables vs Faibles marges).
- [ ] **Tâche 9.2** : Développer l'écran Créances Clients (Liste des débiteurs, montant dû, nombre de jours d'ancienneté).
- [ ] **Tâche 9.3** : Développer l'écran Équipe (Performances par vendeur : ventes, CA, commissions, annulations).
- [ ] **Tâche 9.4** : Développer le Centre d'Alertes et le journal d'anomalies anti-fraude.

### Module 10 : Tests Globaux, Durcissement & Livraison
- [ ] **Tâche 10.1** : Exécuter la suite complète de tests automatisés (Desktop + Mobile + Backend).
- [ ] **Tâche 10.2** : Validation de l'analyse statique (`flutter analyze` vierge sur tous les packages).
- [ ] **Tâche 10.3** : Test en conditions réelles de coupure et rétablissement réseau.
