/// Textes légaux complets (Conditions Générales d'Utilisation et Politique de Confidentialité)
/// pour l'application N'MaShop Desktop.
abstract final class LegalContent {
  static const String termsOfServiceTitle = "Conditions Générales d'Utilisation (CGU)";

  static const String termsOfServiceText = '''
BIENVENUE DANS N'MASHOP DESKTOP

VEUILLEZ LIRE ATTENTIVEMENT LES PRÉSENTES CONDITIONS GÉNÉRALES D'UTILISATION AVANT D'UTILISER L'APPLICATION. EN COCHANT LA CASE D'ACCEPTATION, VOUS ACCEPTEZ D'ÊTRE LIÉ PAR CES CONDITIONS.

1. OBJET ET DESCRIPTION DU SERVICE
N'MaShop est un logiciel de gestion commerciale, de caisse et de suivi de stock destiné aux commerçants et entreprises. L'application fonctionne en architecture hors-ligne (Offline-First) avec stockage local des données sur l'ordinateur de l'utilisateur.

2. LICENCE D'UTILISATION ET PROPRIÉTÉ INTELLECTUELLE
N'MaShop vous accorde une licence non exclusive, personnelle et non transférable d'utilisation du logiciel. Tous les droits de propriété intellectuelle relatifs au logiciel, à son code source, son design et sa marque restent la propriété exclusive de N'MaShop.

3. SÉCURITÉ ET RESPONSABILITÉ DES DONNÉES
L'utilisateur est le seul et unique responsable de la sauvegarde de ses données locales (ventes, stocks, écritures) ainsi que de la confidentialité des identifiants et mots de passe administrateur créés lors du paramétrage. N'MaShop ne saurait être tenu responsable d'une perte de données consécutive à une panne matérielle du poste de travail.

4. CONDITIONS DE REINTIALISATION ET SUPPRESSION
Toute opération de réinitialisation initiée depuis l'application purge définitivement la base de données locale. Il incombe à l'utilisateur de procéder à un export préalable s'il souhaite conserver ses registres comptables.

5. MISES À JOUR ET ÉVOLUTIONS
Des mises à jour correctives et fonctionnelles peuvent être déployées périodiquement. L'installation de ces mises à jour garantit la stabilité et la sécurité continue de l'application.

6. LOI APPLICABLE ET JURIDICTION
Les présentes conditions sont régies par les lois en vigueur. Tout litige relatif à leur interprétation ou leur exécution sera soumis aux juridictions compétentes.
''';

  static const String privacyPolicyTitle = "Politique de Confidentialité et Protection des Données";

  static const String privacyPolicyText = '''
POLITIQUE DE CONFIDENTIALITÉ - N'MASHOP

LA PROTECTION DE VOS DONNÉES COMMERCIALES EST NOTRE PRIORITÉ ABSOLUE.

1. PHILOSOPHIE "OFFLINE-FIRST" (TRAITEMENT LOCAL)
N'MaShop est conçu pour fonctionner de manière autonome sans nécessiter de connexion Internet permanente. Toutes vos transactions, votre catalogue de produits, les noms de vos clients et votre chiffre d'affaires restent stockés localement sur votre disque dur dans une base de données chiffrée et sécurisée.

2. COLLECTE DE DONNÉES DE LICENCE & SYNCHRONISATION
Dans le cadre du contrôle de validité des licences d'utilisation, l'application transmet de manière sécurisée et chiffrée uniquement :
- L'identifiant matériel unique de l'ordinateur (Device Hardware ID)
- La clé de licence saisie et le nom commercial déclaré
- Le statut d'activation (Essai ou Licence active)

Aucune donnée nominative de vos clients ou détails financiers de vos ventes n'est transmise à nos serveurs.

3. SÉCURITÉ DE VOS MOTS DE PASSE
Les mots de passe des comptes administrateurs et vendeurs sont hachés localement avec l'algorithme PBKDF2-HMAC-SHA256 associant un sel aléatoire de 16 octets. Aucun mot de passe n'est stocké en clair.

4. EXPORT ET DÉTENCTION DES DONNÉES
Vous restez le propriétaire exclusif de toutes les données saisies dans N'MaShop. L'application intègre des fonctionnalités d'exportation vers les formats standards (PDF, Excel/CSV) vous permettant de sauvegarder ou migrer vos informations à tout moment.

5. CONTACT
Pour toute question concernant la confidentialité ou le traitement de vos données, vous pouvez contacter le support à support@nmashop.gn.
''';
}
