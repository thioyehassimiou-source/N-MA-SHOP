# Compilation et Déploiement

Cette section est destinée aux techniciens chargés de packager et de distribuer N'MaShop. L'application étant développée avec Flutter, elle peut être générée pour plusieurs cibles à partir de la même base de code.

> **Note Importante :** Contrairement au web, il n'est pas possible d'installer un fichier `.apk` (Android) sur une machine Linux/Windows nativement. Chaque plateforme nécessite son propre format d'exécutable généré spécifiquement pour elle.

## Pré-requis de l'environnement de Build

- **Flutter SDK** : Version 3.10 ou supérieure.
- **Pour Linux** : `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`.
- **Pour Windows** : Visual Studio 2022 avec les composants C++ ("Desktop development with C++").
- **Pour Android** : Android Studio, Android SDK Build-Tools.

## 1. Compiler pour Linux

Si vous êtes sur une machine Linux (ex: Ubuntu), lancez la commande suivante à la racine du projet :

```bash
flutter clean
flutter pub get
flutter build linux
```

Le résultat se trouvera dans le dossier :
`/build/linux/x64/release/bundle/`

**Déploiement :** Vous devez copier **tout le contenu** du dossier `bundle/` (incluant le fichier `nmashop` ainsi que les sous-dossiers `lib/` et `data/`) sur la machine cible. Vous pouvez zipper ce dossier pour le distribuer.

## 2. Compiler pour Android (Tablettes / Smartphones)

Pour générer le fichier d'installation APK, exécutez la commande :

```bash
flutter build apk --release
```

Le fichier APK sera généré dans :
`/build/app/outputs/flutter-apk/app-release.apk`

**Déploiement :** Transférez ce fichier `.apk` sur la tablette Android et ouvrez-le pour l'installer (vous devrez autoriser l'installation d'applications de sources inconnues sur l'appareil).

## 3. Compiler pour Windows

**Attention :** Vous ne pouvez compiler pour Windows que depuis une machine tournant sous Windows. Si vous êtes sous Linux, vous devez transférer le code source vers un PC Windows, y installer Flutter, et lancer :

```cmd
flutter clean
flutter pub get
flutter build windows
```

Le résultat se trouvera dans le dossier :
`\build\windows\runner\Release\`

**Déploiement :** Comme pour Linux, vous devez distribuer la totalité des fichiers générés (fichiers `.exe`, `.dll`, et dossiers de données) ou utiliser un outil comme InnoSetup pour créer un installeur propre.
