/// Utilitaire pour générer des noms de fichiers uniques et compatibles pour
/// l'export et l'impression PDF (évite l'erreur GTK sous Linux « Un fichier de
/// ce nom existe déjà dans l'emplacement choisi »).
String safePrintFileName(String prefix) {
  final now = DateTime.now();
  final timestamp =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  final sanitized = prefix.replaceAll(RegExp(r'[^\w\-]'), '_');
  return '${sanitized}_$timestamp';
}
