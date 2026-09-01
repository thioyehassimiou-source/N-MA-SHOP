import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../domain/first_run_state.dart';

final firstRunControllerProvider =
    NotifierProvider<FirstRunController, FirstRunState>(
  FirstRunController.new,
);

class FirstRunController extends Notifier<FirstRunState> {
  @override
  FirstRunState build() => const FirstRunState();

  void setStep(int step) {
    if (step >= 0 && step < FirstRunState.totalSteps) {
      state = state.copyWith(currentStep: step);
    }
  }

  void nextStep() {
    if (state.canGoNext && state.currentStep < FirstRunState.totalSteps - 1) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void prevStep() {
    if (state.currentStep > 0 && !state.isCompleting) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void setAcceptedTerms(bool value) {
    state = state.copyWith(acceptedTerms: value);
  }

  void setAcceptedPrivacy(bool value) {
    state = state.copyWith(acceptedPrivacy: value);
  }

  void setCreateDesktopShortcut(bool value) {
    state = state.copyWith(createDesktopShortcut: value);
  }

  void setAutoLaunchAtStartup(bool value) {
    state = state.copyWith(autoLaunchAtStartup: value);
  }

  void setEnableAnalytics(bool value) {
    state = state.copyWith(enableAnalytics: value);
  }

  /// Marque l'assistant au premier démarrage comme terminé dans SharedPreferences.
  Future<void> completeWizard() async {
    if (state.isCompleting) return;
    state = state.copyWith(isCompleting: true);

    try {
      await ref.read(appSettingsProvider.notifier).completeFirstRun(
            createDesktopShortcut: state.createDesktopShortcut,
            autoLaunchAtStartup: state.autoLaunchAtStartup,
          );
    } finally {
      state = state.copyWith(isCompleting: false);
    }
  }
}
