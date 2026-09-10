# N’MaShop — Page Officielle de Distribution SaaS (Windows Desktop V1)

Site web officiel de présentation et de distribution du logiciel **N’MaShop** pour ordinateurs PC Windows (10 & 11, 64-bit), conçu pour les commerçants, boutiques, magasins et grossistes en Guinée et Afrique de l'Ouest.

## 🌟 Points Forts & Spécifications Réelles

- **Identité Officielle N'MaShop** : Logo officiel avec panier bleu et poignées orange (`Gérer · Vendre · Grandir`).
- **Plateforme Cible Réelle** : Logiciel Desktop **Windows 10 / 11 (64-bit)** (Installateur `.exe` et archive portable `.zip`).
- **Piliers Fonctionnels Réels de N'MaShop** :
  - Ventes & Caisse rapide (POS) avec impression de tickets thermiques et factures PDF.
  - Carnet numérique des crédits clients (remplacement du cahier papier).
  - Gestion du stock en temps réel avec valorisation au Coût Moyen Pondéré (CMP).
  - Comptabilité SYSCOHADA (Journal, Grand Livre, Balance) conforme OHADA.
  - Dépenses, flux de caisse et bénéfice net.
  - Suivi des vendeurs & commissions.
  - **100% Hors-Ligne (Offline-First)** : Base locale SQLite ultra-rapide sans dépendance internet.
  - **Essai gratuit de 7 jours** intégré dès le premier lancement.
- **Design SaaS Haut de Gamme** : Navigation en verre poli (glassmorphism), mockup de fenêtre Windows interactif avec vue réelle de caisse en GNF, cartes de comparatif (« Avant sur cahier » vs « Avec N'MaShop »).
- **Configuration Centralisée** : Modifier le lien de téléchargement Windows ou le WhatsApp officiel en 1 seul endroit dans `assets/js/config.js`.

---

## ⚙️ Configuration des Liens (Google Drive & WhatsApp)

Dans `assets/js/config.js` :

```javascript
const CONFIG = {
  APP_NAME: "N’MaShop",
  APP_VERSION: "1.0.0",
  APP_SIZE: "48 Mo",
  APP_OS: "Windows 10 / 11 (64-bit)",
  
  // 🔗 Mettez ici le lien Google Drive de votre installateur Windows (.exe) :
  DOWNLOAD_URL: "https://drive.google.com/file/d/VOTRE_ID_FICHIER_EXE/view",
  
  // 💬 Mettez ici votre numéro WhatsApp officiel (format international, ex: 224620000000) :
  WHATSAPP_URL: "https://wa.me/224620000000?text=Bonjour%20l%27%C3%A9quipe%20N%E2%80%99MaShop",
  WHATSAPP_DISPLAY: "+224 620 00 00 00"
};
```

Tous les boutons de téléchargement de la page pointent automatiquement vers ce lien.

---

## 💻 Test en Local

Le serveur est déjà actif sur votre machine. Pour ouvrir la page :
👉 **`http://localhost:8080`**

Si vous devez relancer le serveur manuellement :
```bash
python3 -m http.server 8080 --directory distribution
```
