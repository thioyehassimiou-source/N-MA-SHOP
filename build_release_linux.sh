#!/bin/bash
# Script d'assemblage de la version RELEASE optimisée pour les clients (Clients PCs)
echo "📦 Compilation de N'MaShop en version RELEASE cliente..."

# Nettoyage préalable
flutter clean
flutter pub get

# Compilation native optimisée AOT avec obfuscation binaire totale (Levier 1 Sécurité)
mkdir -p build/symbols
flutter build linux --release --obfuscate --split-debug-info=build/symbols

echo "✅ Compilation RELEASE obfusquée terminée avec succès !"
echo "🛡️  Symboles de débogage extraits dans : build/symbols/"
echo "📁 Le binaire natif sécurisé et allégé se trouve dans :"
echo "   build/linux/x64/release/bundle/"
