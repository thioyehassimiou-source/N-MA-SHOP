@echo off
REM ==============================================================================
REM Script d'assemblage RELEASE sécurisé pour Windows (Clients N'MaShop Guinée)
REM Levier 1 Sécurité : Compilation AOT + Obfuscation native + Extraction symboles
REM ==============================================================================

echo [1/3] Nettoyage et preparation...
call flutter clean
call flutter pub get

echo [2/3] Creation du dossier de symboles...
if not exist build\symbols mkdir build\symbols

echo [3/3] Compilation native AOT obfusquee (Protection Anti-Reverse Engineering)...
call flutter build windows --release --obfuscate --split-debug-info=build\symbols

echo.
echo ==============================================================================
echo [SUCCES] Compilation Windows RELEASE terminee avec succes !
echo Levier 1 actif : Code obfusque, symboles prives extraits dans build\symbols\
echo Le dossier d'installation client se trouve dans :
echo build\windows\x64\runner\Release\
echo ==============================================================================
pause
