/**
 * Configuration Officielle N’MaShop — Distribution Guinée (Windows PC)
 * Tarifs synchronisés avec le système de génération des licences N'MaShop
 */
const CONFIG = {
  APP_NAME: "N’MaShop",
  APP_SLOGAN: "Gérer · Vendre · Grandir",
  APP_VERSION: "1.1.9",
  APP_SIZE: "82 Mo",
  APP_OS: "Windows 10 / 11 (64-bit)",
  APP_ARCH: "x64 (PC de bureau & Ordinateurs portables)",
  LAST_UPDATE: "Septembre 2026",
  LICENSE_TRIAL: "7 jours d'essai gratuit complet (100% hors-ligne, sans engagement)",
  
  // Liens de téléchargement du logiciel Windows & Multiplateforme
  DOWNLOAD_URL: "https://github.com/thioyehassimiou-source/N-MA-SHOP/releases/download/v1.1.9/NMaShop_Installer.zip",
  DOWNLOAD_PORTABLE_URL: "https://github.com/thioyehassimiou-source/N-MA-SHOP/releases/download/v1.1.9/NMaShop_Windows_Portable_v1.1.9.zip",
  DOWNLOAD_LINUX_URL: "downloads/nmashop_linux_release.tar.gz",
  DOWNLOAD_APK_URL: "downloads/NMaShop_Admin_Mobile_v1.1.9.apk",
  
  // Auteur & Conception Réelle (Transparence Fondateur)
  DEV_NAME: "Hassimiou Thioye",
  DEV_TITLE: "Développeur & Concepteur N'MaShop (Université de Labé)",
  DEV_EMAIL: "thioyehassimiou@gmail.com",
  DEV_LOCATION: "Labé & Conakry, Guinée",

  // Vidéo de démonstration locale
  DEMO_VIDEO_PATH: "assets/video/nmashop_demo_web.mp4",

  // Contacts officiels Guinée
  WHATSAPP_PHONE: "224624193069",
  WHATSAPP_URL: "https://wa.me/224624193069?text=Bonjour%20l%27%C3%A9quipe%20N%E2%80%99MaShop%2C%20je%20souhaite%20en%20savoir%20plus%20sur%20le%20logiciel%20de%20caisse.",
  WHATSAPP_DISPLAY: "+224 624 19 30 69",
  
  // TARIFS OFFICIELS PRÉDÉFINIS (Gestion des Licences N'MaShop)
  PRICING: {
    TRIAL: {
      NAME: "Essai Découverte",
      PRICE: "0 GNF",
      PERIOD: "7 jours offerts",
      BADGE: "100% Gratuit",
      DESC: "Installez et commencez à vendre immédiatement sur votre PC sans carte ni engagement.",
      FEATURES: [
        "Toutes les fonctionnalités débloquées",
        "Fonctionne 100% hors-ligne (zéro coupure)",
        "Ventes et caisse illimitées pendant 7j",
        "Gestion du stock et alertes de seuil bas",
        "Carnet de crédits clients numérique",
        "Aucune carte ni moyen de paiement requis"
      ],
      CTA: "Télécharger l'essai gratuit 7 jours",
      ACTION: "download"
    },
    MONTHLY: {
      NAME: "Licence Mensuelle",
      PRICE: "150 000 GNF",
      PERIOD: "/ mois",
      BADGE: "Flexibilité sans engagement",
      DESC: "Idéal pour équiper votre commerce avec un budget maîtrisé mois par mois.",
      FEATURES: [
        "Ventes et encaissements illimités",
        "Tickets de caisse & factures professionnelles",
        "Suivi du stock en temps réel (CMP)",
        "Gestion des créances clients & relances",
        "Comptabilité de base & clôture de caisse",
        "Sauvegarde Cloud automatique sécurisée",
        "Mises à jour et assistance incluses"
      ],
      CTA: "Prendre l'offre Mensuelle",
      ACTION: "whatsapp",
      WHATSAPP_LINK: "https://wa.me/224624193069?text=Bonjour%20N%27MaShop%2C%20je%20souhaite%20activer%20la%20Licence%20Mensuelle%20(150%20000%20GNF%20-%20R%C3%A9f%20%3A%20LIC-MENS)"
    },
    ANNUAL: {
      NAME: "Licence Annuelle",
      PRICE: "1 500 000 GNF",
      MONTHLY_EQUIVALENT: "soit 125 000 GNF / mois",
      PERIOD: "/ an (365 jours)",
      BADGE: "2 MOIS OFFERTS · LE + POPULAIRE",
      POPULAR: true,
      SAVINGS: "Économisez 300 000 GNF par an",
      DESC: "La formule préférée des magasins pour une année entière de sérénité.",
      FEATURES: [
        "Tous les avantages de la licence mensuelle",
        "Soit 125 000 GNF/mois (2 mois complets offerts)",
        "Thèmes de caisse personnalisés exclusifs",
        "Rapports financiers détaillés & Bilan (PDF/CSV)",
        "Gestion multi-vendeurs avec commissions",
        "Sauvegardes Cloud automatiques (Backblaze B2)",
        "Support technique prioritaire WhatsApp 7j/7"
      ],
      CTA: "Choisir la formule Annuelle",
      ACTION: "whatsapp",
      WHATSAPP_LINK: "https://wa.me/224624193069?text=Bonjour%20N%27MaShop%2C%20je%20souhaite%20activer%20la%20Licence%20Annuelle%20(1%20500%20000%20GNF%20-%20R%C3%A9f%20%3A%20LIC-ANN)"
    },
    LIFETIME: {
      NAME: "Licence À Vie",
      PRICE: "3 500 000 GNF",
      PERIOD: "Paiement unique définitif",
      BADGE: "Rentabilité Maximale",
      DESC: "Achetez le logiciel une fois pour toutes. Aucun abonnement récurrent à payer.",
      FEATURES: [
        "Utilisation illimitée à vie sur votre PC",
        "Aucun abonnement mensuel ni annuel récurrent",
        "Base de données locale définitivement à vous",
        "Toutes les fonctionnalités présentes et futures",
        "Thèmes exclusifs Annuel / À Vie débloqués",
        "Sauvegardes Cloud automatiques incluses",
        "Accompagnement VIP et assistance directe"
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
