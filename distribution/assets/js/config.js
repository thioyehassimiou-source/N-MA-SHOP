/**
 * Configuration Officielle N’MaShop — Distribution Guinée (Windows PC)
 * Tarifs synchronisés avec le système de génération des licences N'MaShop
 */
const CONFIG = {
  APP_NAME: "N’MaShop",
  APP_SLOGAN: "Gérer · Vendre · Grandir",
  APP_VERSION: "1.0.0",
  APP_SIZE: "48 Mo",
  APP_OS: "Windows 10 / 11 (64-bit)",
  APP_ARCH: "x64 (PC de bureau & Ordinateurs portables)",
  LAST_UPDATE: "Septembre 2026",
  LICENSE_TRIAL: "7 jours d'essai gratuit complet (100% hors-ligne)",
  
  // Liens de téléchargement du logiciel Windows & Multiplateforme (Drive Officiel Windows)
  DOWNLOAD_URL: "https://drive.google.com/uc?export=download&id=1grZnk2MUdO7yKHpT-EO4MsO7TduLbYNm",
  DOWNLOAD_PORTABLE_URL: "https://drive.google.com/uc?export=download&id=1grZnk2MUdO7yKHpT-EO4MsO7TduLbYNm",
  DOWNLOAD_LINUX_URL: "downloads/nmashop_linux_release.tar.gz",
  DOWNLOAD_APK_URL: "https://drive.google.com/uc?export=download&id=1yHueBEciq3z7Xh4dKOafJoY3OHN3ZsAN",
  
  // Auteur & Conception Réelle (Conforme AppContacts & Cahier des Charges)
  DEV_NAME: "Hassimiou Thioye",
  DEV_TITLE: "Développeur & Concepteur N'MaShop",
  DEV_EMAIL: "thioyehassimiou@gmail.com",
  DEV_LOCATION: "Labé & Conakry, Guinée",

  // Vidéo de démonstration locale (issue du dossier audio_demo)
  DEMO_VIDEO_PATH: "assets/video/nmashop_demo_with_sound.mp4",
  DEMO_AUDIO_PATH: "assets/audio/voix_off_complete.mp3",

  // Contacts officiels Guinée
  WHATSAPP_PHONE: "224624193069",
  WHATSAPP_URL: "https://wa.me/224624193069?text=Bonjour%20l%27%C3%A9quipe%20N%E2%80%99MaShop%2C%20je%20souhaite%20activer%20une%20licence%20pour%20ma%20boutique.",
  WHATSAPP_DISPLAY: "+224 624 19 30 69",
  
  // TARIFS OFFICIELS PRÉDÉFINIS (Gestion des Licences N'MaShop)
  PRICING: {
    TRIAL: {
      NAME: "Essai Découverte",
      PRICE: "0 GNF",
      PERIOD: "7 jours offerts",
      BADGE: "Sans engagement",
      DESC: "Installez et commencez à vendre immédiatement sur votre PC.",
      FEATURES: [
        "Toutes les fonctionnalités débloquées",
        "Fonctionne 100% hors-ligne (zéro coupure)",
        "Ventes et caisse illimitées",
        "Gestion du stock et alertes de seuil",
        "Carnet de crédits clients numérique",
        "Aucune carte bancaire requise"
      ],
      CTA: "Démarrer l'essai 7 jours",
      ACTION: "download"
    },
    MONTHLY: {
      NAME: "Licence Mensuelle",
      PRICE: "150 000 GNF",
      PERIOD: "/ mois (30 jours)",
      BADGE: "Flexibilité totale",
      DESC: "Idéal pour équiper votre commerce avec un budget maîtrisé mois par mois.",
      FEATURES: [
        "Ventes et encaissements illimités",
        "Tickets de caisse & factures professionnelles",
        "Suivi du stock en temps réel (CMP)",
        "Gestion des créances clients & relances",
        "Comptabilité de base & clôture de caisse",
        "Mises à jour et assistance incluses"
      ],
      CTA: "Prendre l'offre Mensuelle",
      ACTION: "whatsapp",
      WHATSAPP_LINK: "https://wa.me/224624193069?text=Bonjour%20N%27MaShop%2C%20je%20souhaite%20activer%20la%20Licence%20Mensuelle%20(150%20000%20GNF%20-%20R%C3%A9f%20%3A%20LIC-MENS)"
    },
    ANNUAL: {
      NAME: "Licence Annuelle",
      PRICE: "1 500 000 GNF",
      PERIOD: "/ an (365 jours)",
      BADGE: "2 MOIS OFFERTS · RECOMMANDÉ",
      POPULAR: true,
      SAVINGS: "Économisez 300 000 GNF",
      DESC: "La formule favorite des boutiques et magasins pour toute une année de sérénité.",
      FEATURES: [
        "Tous les avantages de la licence mensuelle",
        "Comptabilité complète SYSCOHADA (Journal, Balance)",
        "Gestion multi-vendeurs avec commissions",
        "2 mois complets offerts (1 500 000 au lieu de 1 800 000)",
        "Sauvegardes automatiques sécurisées",
        "Support technique prioritaire WhatsApp 7j/7"
      ],
      CTA: "Choisir la formule Annuelle",
      ACTION: "whatsapp",
      WHATSAPP_LINK: "https://wa.me/224624193069?text=Bonjour%20N%27MaShop%2C%20je%20souhaite%20activer%20la%20Licence%20Annuelle%20(1%20500%20000%20GNF%20-%20R%C3%A9f%20%3A%20LIC-ANN)"
    },
    LIFETIME: {
      NAME: "Licence À Vie",
      PRICE: "3 500 000 GNF",
      PERIOD: "Paiement unique",
      BADGE: "Investissement Définitif",
      DESC: "Achetez le logiciel une fois pour toutes. Zéro abonnement récurrent à payer.",
      FEATURES: [
        "Utilisation illimitée à vie sur votre PC",
        "Aucun abonnement mensuel ni annuel",
        "Base de données locale définitivement à vous",
        "Toutes les fonctionnalités présentes et futures",
        "Gestion complète Stock, Ventes, Crédits, Compta",
        "Accompagnement VIP et formation sur mesure"
      ],
      CTA: "Acquérir la Licence À Vie",
      ACTION: "whatsapp",
      WHATSAPP_LINK: "https://wa.me/224624193069?text=Bonjour%20N%27MaShop%2C%20je%20souhaite%20activer%20la%20Licence%20%C3%80%20Vie%20(3%20500%20000%20GNF%20-%20R%C3%A9f%20%3A%20LIC-VIE)"
    }
  },
  
  CURRENCY: "GNF",
  COUNTRY: "Guinée"
};

if (typeof module !== "undefined" && module.exports) {
  module.exports = CONFIG;
}
