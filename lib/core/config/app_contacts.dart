/// Coordonnées commerciales et support officielles de N'MaShop.
abstract final class AppContacts {
  static const String developerName = 'Hassimiou Thioye';
  static const String developerTitle = 'Développeur & Concepteur N\'MaShop';
  static const String phone = '+224 624 19 30 69';
  static const String phoneRaw = '224624193069';
  static const String email = 'thioyehassimiou@gmail.com';

  /// Génère le lien WhatsApp avec message pré-rempli pour la commande de licence.
  static String getWhatsAppOrderUrl({required String referenceCode}) {
    final msg = Uri.encodeComponent(
      'Bonjour N\'MaShop, je souhaite activer mon logiciel. (Réf : $referenceCode)',
    );
    return 'https://wa.me/$phoneRaw?text=$msg';
  }

  /// Génère le lien WhatsApp avec message pré-rempli pour le support technique.
  static String getWhatsAppSupportUrl() {
    final msg = Uri.encodeComponent(
      'Bonjour l\'équipe N\'MaShop, j\'ai besoin d\'une assistance technique concernant mon logiciel.',
    );
    return 'https://wa.me/$phoneRaw?text=$msg';
  }
}
