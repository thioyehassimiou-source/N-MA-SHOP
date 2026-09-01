import 'package:flutter/foundation.dart';

/// Modèle d'état représentant la progression et les choix de l'assistant au premier démarrage.
@immutable
class FirstRunState {
  const FirstRunState({
    this.currentStep = 0,
    this.acceptedTerms = false,
    this.acceptedPrivacy = false,
    this.createDesktopShortcut = true,
    this.autoLaunchAtStartup = false,
    this.enableAnalytics = false,
    this.isCompleting = false,
  });

  /// Index de l'étape courante (0 à 5).
  final int currentStep;

  /// Acceptance des Conditions Générales d'Utilisation (Étape 2).
  final bool acceptedTerms;

  /// Acceptance de la Politique de Confidentialité (Étape 3).
  final bool acceptedPrivacy;

  /// Option : Créer un raccourci sur le bureau (Étape 4).
  final bool createDesktopShortcut;

  /// Option : Lancer automatiquement l'application au démarrage du PC (Étape 4).
  final bool autoLaunchAtStartup;

  /// Option : Autoriser la télémétrie anonyme (Étape 4).
  final bool enableAnalytics;

  /// Indique si la sauvegarde de fin est en cours.
  final bool isCompleting;

  /// Nombre total d'étapes de l'assistant.
  static const int totalSteps = 6;

  bool get canGoNext {
    switch (currentStep) {
      case 0:
        return true;
      case 1:
        return acceptedTerms;
      case 2:
        return acceptedPrivacy;
      case 3:
        return true;
      case 4:
        return acceptedTerms && acceptedPrivacy;
      case 5:
        return true;
      default:
        return false;
    }
  }

  FirstRunState copyWith({
    int? currentStep,
    bool? acceptedTerms,
    bool? acceptedPrivacy,
    bool? createDesktopShortcut,
    bool? autoLaunchAtStartup,
    bool? enableAnalytics,
    bool? isCompleting,
  }) {
    return FirstRunState(
      currentStep: currentStep ?? this.currentStep,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
      acceptedPrivacy: acceptedPrivacy ?? this.acceptedPrivacy,
      createDesktopShortcut: createDesktopShortcut ?? this.createDesktopShortcut,
      autoLaunchAtStartup: autoLaunchAtStartup ?? this.autoLaunchAtStartup,
      enableAnalytics: enableAnalytics ?? this.enableAnalytics,
      isCompleting: isCompleting ?? this.isCompleting,
    );
  }
}
