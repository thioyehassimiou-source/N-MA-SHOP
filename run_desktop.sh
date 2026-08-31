#!/bin/bash
# Script de lancement optimisé pour éviter le plantage/verrouillage de Linux (OOM RAM Spike)
echo "🚀 Lancement de N'MaShop avec limitation du parallélisme de compilation (2 threads max)..."
export CMAKE_BUILD_PARALLEL_LEVEL=2
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
flutter run -d linux "$@"
