#!/usr/bin/env bash
# ==============================================================================
# Script de compilation de l'application Customer Mobile (APK Android Commerçant)
# N'MaShop POS Mobile
# ==============================================================================

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📱 ============================================================="
echo "    N'MaShop Customer Mobile — Compilation Locale de l'APK"
echo "============================================================="

# 1. Détection de Flutter
if command -v flutter &> /dev/null; then
    FLUTTER_CMD="flutter"
elif [ -f "$HOME/development/flutter/bin/flutter" ]; then
    export PATH="$HOME/development/flutter/bin:$PATH"
    FLUTTER_CMD="$HOME/development/flutter/bin/flutter"
else
    echo "❌ Flutter n'a pas été trouvé."
    exit 1
fi

echo "✅ Flutter détecté : $($FLUTTER_CMD --version | head -n 1)"

# 2. Compilation Release APK
cd "$DIR/apps/customer_mobile"
echo "📦 Récupération des dépendances..."
$FLUTTER_CMD pub get

if [ -f "android/gradlew" ]; then
    chmod +x android/gradlew
fi

echo "🔨 Compilation de l'APK Android (Release)..."
$FLUTTER_CMD build apk --release --android-skip-build-dependency-validation

# 3. Récupération et copie du binaire
OUTPUT_APK="$DIR/apps/customer_mobile/build/app/outputs/flutter-apk/app-release.apk"
DEST_APK="$DIR/distribution/downloads/NMaShop_Mobile_v1.2.0.apk"
ROOT_APK="$DIR/NMaShop_Mobile_v1.2.0.apk"

if [ -f "$OUTPUT_APK" ]; then
    mkdir -p "$DIR/distribution/downloads"
    cp "$OUTPUT_APK" "$DEST_APK"
    cp "$OUTPUT_APK" "$ROOT_APK"
    echo ""
    echo "🎉 ============================================================="
    echo "    APK CUSTOMER MOBILE GÉNÉRÉ AVEC SUCCÈS !"
    echo "    Emplacement : $ROOT_APK"
    echo "============================================================="
fi
