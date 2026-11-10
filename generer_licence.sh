#!/bin/bash
# Script de lancement du Générateur de Licences N'MaShop

set -e

# Recherche de flutter/dart dans les emplacements habituels
COMMON_PATHS=(
    "$HOME/flutter/bin"
    "$HOME/development/flutter/bin"
    "$HOME/dev/flutter/bin"
    "$HOME/src/flutter/bin"
    "$HOME/.local/share/flutter/bin"
    "/snap/flutter/current/bin"
    "/opt/flutter/bin"
)

for p in "${COMMON_PATHS[@]}"; do
    if [ -x "$p/flutter" ] && [[ ":$PATH:" != *":$p:"* ]]; then
        export PATH="$p:$p/cache/dart-sdk/bin:$PATH"
        break
    fi
done

DART_CMD="dart"
if ! command -v dart &> /dev/null; then
    if command -v flutter &> /dev/null; then
        FLUTTER_BIN="$(dirname "$(which flutter)")"
        if [ -x "$FLUTTER_BIN/cache/dart-sdk/bin/dart" ]; then
            DART_CMD="$FLUTTER_BIN/cache/dart-sdk/bin/dart"
        else
            DART_CMD="flutter pub run"
        fi
    fi
fi

exec $DART_CMD run tools/generate_license.dart "$@"
