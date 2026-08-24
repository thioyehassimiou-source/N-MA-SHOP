# Comment générer l'installeur N'MaShop pour Windows

Puisque vous développez actuellement sous Linux, vous ne pouvez pas générer directement un exécutable (`.exe`) pour Windows. Vous devez utiliser un ordinateur fonctionnant sous **Windows** pour l'étape finale.

Suivez ces étapes simples pour transformer votre code en un **vrai logiciel professionnel** prêt à être distribué.

## Étape 1 : Préparer l'environnement (Sur l'ordinateur Windows)

1. Installez **Flutter** pour Windows.
2. Installez **Visual Studio** avec le module "Développement Desktop en C++".
3. Installez **Inno Setup** (logiciel gratuit pour créer des installeurs) : [https://jrsoftware.org/isdl.php](https://jrsoftware.org/isdl.php)

## Étape 2 : Copier le projet et l'Icône

1. Copiez tout le dossier de votre projet `nmashop` sur l'ordinateur Windows.
2. **Ajoutez votre Logo** :
   Prenez le logo de votre logiciel (au format `.ico`, taille recommandée 256x256) et remplacez le fichier suivant :
   `windows\runner\resources\app_icon.ico`
   *Cela permettra à l'application d'avoir votre logo dans la barre des tâches de Windows et sur le bureau.*

## Étape 3 : Ajouter les images de l'installeur (Optionnel mais recommandé)

Pour avoir un installeur d'aspect très professionnel (avec des images de fond et une icône lors de l'installation) :
1. Créez un dossier nommé `Images` dans le dossier `windows` (soit `nmashop\windows\Images`).
2. Créez et placez-y une image `setup_bg.bmp` (164x314 pixels) pour l'illustration sur le côté.
3. Créez et placez-y une image `setup_icon.bmp` (55x55 pixels) pour l'icône en haut à droite.
4. Ouvrez `windows\setup.iss` et enlevez le point-virgule (`;`) au début de ces deux lignes :
   ```ini
   WizardImageFile=Images\setup_bg.bmp
   WizardSmallImageFile=Images\setup_icon.bmp
   ```

## Étape 4 : Compiler l'application

Ouvrez un terminal (PowerShell ou Invite de commandes) dans le dossier du projet et lancez :
```bash
flutter build windows --release
```
Cette commande va prendre tout votre code et générer l'exécutable natif dans le dossier `build\windows\x64\runner\Release`.

## Étape 5 : Créer l'Installeur Final avec les Conditions d'Utilisation

1. Ouvrez le logiciel **Inno Setup Compiler** sur Windows.
2. Cliquez sur **File > Open** et sélectionnez le fichier `windows\setup.iss` de votre projet.
3. Cliquez sur le bouton **Compile** (ou la flèche verte "Run").
4. Inno Setup va automatiquement packager votre application avec le fichier de licence (`EULA.txt`) que nous avons créé. L'utilisateur devra cocher "J'accepte les termes du contrat" pour l'installer.

🎉 **C'est fini !** 
Vous trouverez votre fichier d'installation professionnel dans le dossier `build\windows\NMaShop_Setup_v1.0.0.exe`. Vous pouvez l'envoyer à vos clients pour qu'ils l'installent !
