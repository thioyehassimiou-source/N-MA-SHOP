#!/bin/bash
# Lancement de l'Espace Graphique Administrateur N'MaShop (Gestion des clients et des licences)
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR/apps/admin_mobile"

echo "🚀 Lancement de l'application Administrateur N'MaShop..."
export CMAKE_BUILD_PARALLEL_LEVEL=2
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"

flutter run -d linux "$@"

