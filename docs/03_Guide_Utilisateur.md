# Guide Utilisateur

Ce guide décrit l'utilisation quotidienne de l'application N'MaShop pour un commerçant ou un caissier.

## 1. Initialisation (Configuration Initiale)

Au premier lancement de l'application, l'écran "Bienvenue" s'affiche.
1. Renseignez les informations de base de votre boutique (Nom, Secteur, Monnaie).
2. Créez le compte **Administrateur** principal.
3. Le système vous dirigera ensuite vers le Tableau de bord.

## 2. Rôles et Sécurité (RBAC)

N'MaShop propose deux niveaux d'accès :
- **Administrateur :** A un accès complet. Il peut voir le chiffre d'affaires global, les bénéfices, modifier les paramètres, effacer l'historique et gérer les stocks.
- **Caissier / Vendeur :** Accès limité. Il peut enregistrer des ventes, imprimer des reçus et consulter le catalogue, mais il n'a pas accès aux statistiques financières ni à la modification des paramètres critiques.

## 3. Gestion de l'Inventaire (Produits)

1. Allez dans l'onglet **Catalogue**.
2. Cliquez sur **Nouveau Produit** pour ajouter un article manuellement.
   - Vous pouvez associer une image, définir un seuil d'alerte (pour être notifié quand le stock est bas), et renseigner les prix.
3. Utilisez le bouton **Importer** pour charger massivement vos produits depuis un fichier CSV.

## 4. Module de Caisse et Ventes

1. Allez dans l'onglet **Nouvelle Vente**.
2. Sélectionnez les articles dans le catalogue ou scannez leur code-barres (si activé).
3. Ajustez les quantités.
4. Au moment du paiement, choisissez la méthode (Espèces, Orange Money, etc.).
5. Si le client ne paie pas la totalité, un reliquat (Crédit) est généré et rattaché au client (onglet "Crédits").
6. **Impression :** À la validation, la facture est générée au format A4 PDF, prête à être imprimée ou sauvegardée.

## 5. Exports et Sauvegardes

Pour prévenir toute perte de données (ordinateur cassé ou volé) :
1. Allez dans **Paramètres > Outils & Sécurité**.
2. Cliquez sur **Sauvegarder la base de données**. Choisissez une clé USB pour exporter le fichier `.sqlite`.
3. Vous pouvez également cliquer sur **Exporter les ventes (CSV)** pour envoyer votre historique à votre comptable sur Excel.
