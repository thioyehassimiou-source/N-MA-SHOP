/// Échelle d'espacement de la charte (en pixels logiques).
/// À utiliser partout à la place de valeurs numériques en dur.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double base = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Largeur de la barre de navigation latérale.
  static const double navWidth = 72;

  /// Largeur maximale du contenu centré.
  static const double containerMax = double.infinity;

  /// Hauteur de la barre supérieure.
  static const double topBarHeight = 64;
}

/// Rayons d'arrondi de la charte (SaaS).
abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 6;
  static const double lg = 8;
  static const double md = 14; // Premium form fields radius
  static const double xl = 12; // Used to be much larger. 12px is maximum for cards.
  static const double full = 9999;
}
