#!/bin/bash
# Script de build Linux optimisé pour éviter les crashs OOM (systemd-oomd)
echo "🚀 Build de N'MaShop Linux avec limitation de parallélisme (2 threads)..."
export CMAKE_BUILD_PARALLEL_LEVEL=2
export NINJAFLAGS="-j2"
export MAKEFLAGS="-j2"
flutter build linux "$@"
