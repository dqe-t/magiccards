# La Roulette Magique (Les Cartes Magiques) 🎡

Un jeu ludo-éducatif conçu pour apprendre les lettres (majuscules/minuscules, noms et sons phonétiques) et les chiffres (1 à 20) en français pour les jeunes enfants.
Développé sous **Godot 4** (compilable vers **Windows**, **Android** et **iOS**).

---

## ✨ Fonctionnalités & Ergonomie Multi-Écrans

* **Dimensionnement Physique Adaptatif (27" Desktop, Tablette 10", Téléphone) :**
  * **Plafond « Vraie Carte à Jouer » sur Grand Écran (27") :** Sur un moniteur 27 pouces, les cartes conservent leur taille idéale d'origine (`210×290 px` en 1080p, soit $\approx 65 \times 90\text{ mm}$, la taille réelle d'une carte à jouer).
  * **Taille Unifiée Définie par 5 Cartes sur Écrans Plus Petits :** Sur les écrans plus petits (tablettes, téléphones), la taille des cartes est déterminée par l'espace disponible pour 5 cartes. Cette taille reste rigoureusement identique que la manche en cours affiche 3, 4 ou 5 cartes.
  * **Grille de Configuration Tactile Adaptative :** Sur grand moniteur, les 26 lettres s'affichent sur une seule ligne ; sur tablette et téléphone, elles se répartissent automatiquement sur deux rangées de 13 (et deux rangées de 10 pour les chiffres) pour des cibles tactiles confortables au doigt.
* **Support Tactile & Souris Natif :** Fonctionne à la souris (avec curseur main personnalisé sur PC) et au toucher sur Android/iOS, avec gestion du bouton Retour Android et de la touche `Échap (ESC)`.

---

## 🎮 Running & Testing

### 1. Lancer le jeu en mode développement
```powershell
# Plein écran natif
godot_console.exe --path .

# Mode fenêtré ou simulation d'un écran physique (ex. tablette 10.1 pouces)
godot_console.exe --path . -- --windowed --width 1280 --height 800 --screen-inches 10.1
```

### 2. Exécuter les tests unitaires Godot (Headless)
```powershell
godot_console.exe --headless --path . -s res://tests/godot/test_runner.gd
```

---

## 📦 Compilation & Distribution Autonome

### 1. Prérequis : Modèles d'exportation Godot (Export Templates)
Avant de compiler un exécutable ou un package mobile, téléchargez les modèles correspondant à votre version de Godot (ici Godot 4.7.2) :
* **Via l'Éditeur Godot :** Ouvrez Godot, allez dans `Projet` -> `Gérer les modèles d'exportation...`, puis cliquez sur `Télécharger et installer`.
* **Ou via la ligne de commande :**
  ```powershell
  # Téléchargement et installation automatique des templates
  $ver = "4.7.2.stable"
  $dest = "$env:APPDATA\Godot\export_templates\$ver"
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  Invoke-WebRequest -Uri "https://github.com/godotengine/godot/releases/download/$ver/Godot_v$ver`_export_templates.tpz" -OutFile "$dest\templates.zip"
  Expand-Archive -Path "$dest\templates.zip" -DestinationPath "$dest\temp" -Force
  Move-Item -Path "$dest\temp\templates\*" -Destination $dest -Force
  Remove-Item -Recurse -Force "$dest\temp", "$dest\templates.zip"
  ```

---

### 2. Compiler pour Windows (.exe autonome)

Le preset `Windows Desktop` est configuré dans `export_presets.cfg` avec l'option `embed_pck=true` (ce qui intègre toutes les ressources directement dans le `.exe`).

```powershell
# Créer le répertoire de sortie
New-Item -ItemType Directory -Force -Path dist | Out-Null

# Compiler l'exécutable autonome
godot_console.exe --headless --path . --export-release "Windows Desktop" dist/les_cartes_magiques_godot.exe
```

Le fichier autonome `dist/les_cartes_magiques_godot.exe` peut ensuite être distribué et lancé directement sans dépendance externe.

---

### 3. Compiler pour Android (.apk & .aab)

#### Prérequis spécifiques à Android :
1. **Android SDK & Command-line Tools :**
   * Installez Android Studio ou les `cmdline-tools` (SDK Platforms 33/34 et Build-tools).
2. **OpenJDK 17 :** Installé et disponible dans le `PATH`.
3. **Clé de signature de débogage (debug keystore) ou de release :**
   * Pour le débogage :
     ```powershell
     keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999
     ```
   * Pour la release (Google Play Store), le script `scripts/build_aab.py` provisionne automatiquement `output/keystores/release.keystore`.

#### Compilation de l'APK (Installation directe / Débogage / Sideloading) :
Le preset `Android APK` est configuré avec l'architecture `arm64-v8a` par défaut pour une taille optimisée (~58 Mo).
```powershell
godot_console.exe --headless --path . --export-release "Android APK" dist/les_cartes_magiques.apk
```
Pour installer directement sur un appareil ou émulateur Android connecté par USB :
```powershell
adb install -r dist/les_cartes_magiques.apk
```

#### Compilation de l'Android App Bundle (.aab pour Google Play Store) :
```powershell
python scripts/build_aab.py
```
Le bundle final optimisé (~59 Mo) est automatiquement compilé et copié dans `play_store_assets/les_cartes_magiques.aab`.

---

### 4. Compiler pour iOS (.ipa / Projet Xcode)

Pour compiler vers iOS, une machine sous macOS équipée de Xcode est nécessaire :
```bash
# Génère le projet Xcode complet dans dist/ios/
mkdir -p dist/ios
godot --headless --path . --export-release "iOS" dist/ios/les_cartes_magiques.ipa
```
Ouvrez ensuite le projet généré dans Xcode pour le signer avec votre compte développeur Apple et le déployer sur iPhone/iPad.

---

## 🗜️ Optimisation de la Taille des Paquets & Gestion des Médias Originaux

Le projet intègre une stratégie ciblée de réduction de taille sans compromis sur la qualité visuelle :

### 1. Synthèse des Optimisations Appliquées

| Composant | Avant | Après | Statut & Arbitrage Qualité |
| :--- | :--- | :--- | :--- |
| **Vidéos Récompenses (`.ogv`)** | 58.7 Mo | **58.7 Mo** | **Qualité native préservée :** compression Theora désactivée pour éviter tout artefact de compression visuel sur les animations. |
| **Clips Vocaux (`.mp3`)** | 62.5 Mo | **21.3 Mo** | **Gain majeur (-41 Mo / -66%) :** 874 fichiers vocaux ré-encodés en mono 64 kbps (qualité vocale transparente sans perte perceptible). |
| **Dépollution Export (`tmp/*`)** | 6.2 Mo | **0 Mo** | **Gain de 6.2 Mo (-100%) :** exclusion systématique des vidéos et captures de test dans `export_presets.cfg`. |
| **Architecture Native (`.so`)** | 72.7 Mo (3 ABIs) | **23.3 Mo** | **Gain de 49 Mo (-68%) :** ciblage `arm64-v8a` par défaut pour l'APK direct (évite de tripler le poids du moteur). |

### 2. Préservation des Médias Originaux Haute Définition (`assets_original/`)

Afin de garantir la pérennité des assets :
* **Emplacement des masters :** Tous les fichiers sources audio et vidéo sont archivés intacts dans `assets_original/` (`assets_original/videos/` et `assets_original/audio/`).
* **Protection Godot via `.gdignore` :** Le fichier `assets_original/.gdignore` signale au moteur Godot d'ignorer ce répertoire lors de l'indexation de l'éditeur et lors de l'exportation des paquets.
* **Pipeline d'optimisation automatisé :** En cas d'ajout de nouvelles voix, l'optimisation audio se relance en une seule commande (sans toucher aux vidéos) :
  ```powershell
  python scripts/optimize_assets.py
  ```

---

## 🐍 Version Python Originale
```powershell
pip install -r requirements.txt
python main.py
pytest -v
```
