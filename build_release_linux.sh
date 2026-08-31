#!/bin/bash
# Script d'assemblage de la version RELEASE optimisée pour les clients (Clients PCs)
echo "📦 Compilation de N'MaShop en version RELEASE cliente..."

# Nettoyage préalable
flutter clean
flutter pub get

# Compilation native optimisée AOT sans symboles de debug
flutter build linux --release

echo "✅ Compilation terminée avec succès !"
echo "📁 Le binaire natif ultra-léger pour le client se trouve dans :"
echo "   build/linux/x64/release/bundle/"
