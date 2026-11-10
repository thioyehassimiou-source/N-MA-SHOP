#!/bin/bash
# Script de compilation de l'application Administrateur Mobile (APK Release pour Android)
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR/apps/admin_mobile"

echo "📱 Compilation de l'APK Release N'MaShop Admin Mobile..."
flutter clean
flutter pub get
flutter build apk --release

OUTPUT_APK="$DIR/apps/admin_mobile/build/app/outputs/flutter-apk/app-release.apk"
DEST_APK="$DIR/distribution/downloads/NMaShop_Admin_Mobile_v1.3.0.apk"

if [ -f "$OUTPUT_APK" ]; then
    mkdir -p "$DIR/distribution/downloads"
    cp "$OUTPUT_APK" "$DEST_APK"
    echo "✅ APK généré avec succès !"
    echo "   👉 $DEST_APK"
    echo "   Taille : $(du -h "$DEST_APK" | cut -f1)"
fi

