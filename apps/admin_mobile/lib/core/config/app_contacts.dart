/// Coordonnées commerciales et support officielles de N'MaShop Administrateur.
abstract final class AppContacts {
  static const String developerName = 'Hassimiou Thioye';
  static const String developerTitle = 'Développeur & Concepteur N\'MaShop';
  static const String phone = '+224 624 19 30 69';
  static const String phoneRaw = '224624193069';
  static const String email = 'thioyehassimiou@gmail.com';

  /// Lien WhatsApp direct vers le numéro officiel.
  static String getDirectWhatsAppUrl({String message = ''}) {
    final encoded = Uri.encodeComponent(message);
    return 'https://wa.me/$phoneRaw?text=$encoded';
  }
}
