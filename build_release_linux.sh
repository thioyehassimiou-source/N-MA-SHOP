#!/bin/bash
# Script d'assemblage de la version RELEASE optimisée pour les clients (Clients PCs)
set -e

echo "📦 Compilation de N'MaShop en version RELEASE cliente..."
echo "⚙️  Limitation du parallélisme à 2 threads pour préserver la RAM..."

export CMAKE_BUILD_PARALLEL_LEVEL=2
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"

# 1. Compilation native optimisée AOT avec obfuscation binaire totale (Levier 1 Sécurité)
mkdir -p build/symbols
flutter build linux --release --obfuscate --split-debug-info=build/symbols "$@"

echo "✅ Compilation RELEASE obfusquée terminée avec succès !"
echo "🛡️  Symboles de débogage extraits dans : build/symbols/"
echo "📁 Le binaire natif sécurisé et allégé se trouve dans :"
echo "   build/linux/x64/release/bundle/"

# 2. Ajout du script de lancement autonome dans le bundle
BUNDLE_DIR="build/linux/x64/release/bundle"
cat << 'EOF' > "$BUNDLE_DIR/lancer_nmashop.sh"
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
exec ./nmashop "$@"
EOF
chmod +x "$BUNDLE_DIR/lancer_nmashop.sh"

# 3. Empaquetage de l'archive tar.gz prête pour la distribution
mkdir -p distribution/downloads
echo "📦 Création de l'archive de distribution pour les clients..."
tar -czf distribution/downloads/nmashop_linux_release.tar.gz -C build/linux/x64/release bundle

echo "🎉 Archive client prête à être installée / distribuée :"
echo "   👉 distribution/downloads/nmashop_linux_release.tar.gz"
echo "   Taille : $(du -h distribution/downloads/nmashop_linux_release.tar.gz | cut -f1)"

