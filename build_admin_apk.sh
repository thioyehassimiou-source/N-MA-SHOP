#!/usr/bin/env bash
# ==============================================================================
# Script de compilation locale de l'application Admin Mobile (APK Android)
# N'MaShop v1.3.0
# ==============================================================================

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📱 ============================================================="
echo "    N'MaShop Admin Mobile — Compilation Locale de l'APK"
echo "============================================================="

# 1. Détection de Flutter
if command -v flutter &> /dev/null; then
    FLUTTER_CMD="flutter"
elif [ -f "$HOME/development/flutter/bin/flutter" ]; then
    export PATH="$HOME/development/flutter/bin:$PATH"
    FLUTTER_CMD="$HOME/development/flutter/bin/flutter"
else
    echo "❌ Flutter n'a pas été trouvé. Assurez-vous qu'il est installé dans ~/development/flutter/bin"
    exit 1
fi

echo "✅ Flutter détecté : $($FLUTTER_CMD --version | head -n 1)"

# 2. Vérification de Java
if ! command -v java &> /dev/null; then
    echo "⚠️ Java n'est pas encore installé sur votre système Ubuntu."
    echo "👉 Pour installer Java 17, exécutez :"
    echo "   sudo apt update && sudo apt install -y openjdk-17-jdk"
    echo ""
fi

# 3. Vérification du SDK Android
ANDROID_SDK_PATH="${ANDROID_HOME:-$HOME/Android/Sdk}"
if [ ! -d "$ANDROID_SDK_PATH" ]; then
    echo "⚠️ Le SDK Android n'est pas configuré dans $ANDROID_SDK_PATH."
    echo "👉 Vous pouvez :"
    echo "   - Installer Android Studio (ou cmdline-tools) :"
    echo "     https://developer.android.com/studio"
    echo "   - OU utiliser l'action GitHub dédiée sans rien installer :"
    echo "     Onglet 'Actions' sur GitHub -> '📱 Build Admin Mobile' -> 'Run workflow'."
    echo ""
fi

# 4. Compilation Release APK
cd "$DIR/apps/admin_mobile"
echo "📦 Récupération des dépendances..."
$FLUTTER_CMD pub get

if [ -f "android/gradlew" ]; then
    chmod +x android/gradlew
fi

echo "🔨 Compilation de l'APK Android (Release)..."
$FLUTTER_CMD build apk --release

# 5. Récupération et copie du binaire
OUTPUT_APK="$DIR/apps/admin_mobile/build/app/outputs/flutter-apk/app-release.apk"
DEST_APK="$DIR/distribution/downloads/NMaShop_Admin_Mobile_v1.3.0.apk"
ROOT_APK="$DIR/NMaShop_Admin_Mobile_v1.3.0.apk"

if [ -f "$OUTPUT_APK" ]; then
    mkdir -p "$DIR/distribution/downloads"
    cp "$OUTPUT_APK" "$DEST_APK"
    cp "$OUTPUT_APK" "$ROOT_APK"
    echo ""
    echo "🎉 ============================================================="
    echo "   COMPILATION RÉUSSIE !"
    echo "   APK prêt : $DEST_APK"
    echo "   Taille   : $(du -h "$DEST_APK" | cut -f1)"
    echo "============================================================="
    echo "📲 Pour l'installer sur votre téléphone Android :"
    echo "   1. Par câble USB (si adb est actif) :"
    echo "      adb install -r \"$ROOT_APK\""
    echo "   2. OU copier le fichier sur votre téléphone (Téléchargements, WhatsApp, Google Drive)."
else
    echo "⚠️ Fichier APK introuvable après compilation."
fi
