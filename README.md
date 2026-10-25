# La Roulette Magique (Magic Cards) 🎡

An educational game designed to help young children learn letters (uppercase/lowercase, letter names, and phonetic sounds) and numbers (1 to 20) with bilingual French and English voice support.  
Developed in **Godot 4** (exportable to **Windows**, **Android**, and **iOS**).

---

## ✨ Features & Multi-Screen Ergonomics

* **Physical Adaptive Scaling (27" Desktop, 10" Tablet, 6" Phone):**
  * **"Real Playing Card" Ceiling on Large Displays (27"):** On a 27-inch monitor, cards maintain their ideal physical size (`210×290 px` at 1080p, $\approx 65 \times 90\text{ mm}$, the exact dimensions of a real playing card).
  * **Unified Card Size on Smaller Screens:** On tablets and mobile phones, card size is determined by the screen width available for 5 cards. This size remains strictly consistent whether 3, 4, or 5 cards are dealt.
  * **Adaptive Touch Configuration Grid:** On desktop monitors, all 26 letters fit on a single row; on tablets and phones, letters automatically wrap into two rows of 13 (and numbers into two rows of 10) for comfortable, child-friendly touch targets.
* **Native Touch & Mouse Support:** Smooth operation via mouse (with custom hand cursor on desktop) and multi-touch on Android/iOS, including full handling for the Android hardware Back button and keyboard `Escape (ESC)`.

---

## 🎮 Running & Testing

### 1. Launch the Game in Development Mode
```powershell
# Native fullscreen
godot_console.exe --path .

# Windowed simulation for a physical screen size (e.g., 10.1-inch tablet)
godot_console.exe --path . -- --windowed --width 1280 --height 800 --screen-inches 10.1

# 6-inch phone simulation shortcut
.\run_phone_6inch.bat
```

### 2. Run Headless Godot Unit Tests
```powershell
godot_console.exe --headless --path . -s res://tests/godot/test_runner.gd
```

---

## 📦 Export & Distribution

### 1. Prerequisites: Godot Export Templates
Before exporting binaries, download and install the export templates matching your Godot engine version (Godot 4.7.2):
* **Via Godot Editor:** Navigate to `Project` -> `Manage Export Templates...`, then click `Download and Install`.
* **Via PowerShell CLI:**
  ```powershell
  $ver = "4.7.2.stable"
  $dest = "$env:APPDATA\Godot\export_templates\$ver"
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  Invoke-WebRequest -Uri "https://github.com/godotengine/godot/releases/download/$ver/Godot_v$ver`_export_templates.tpz" -OutFile "$dest\templates.zip"
  Expand-Archive -Path "$dest\templates.zip" -DestinationPath "$dest\temp" -Force
  Move-Item -Path "$dest\temp\templates\*" -Destination $dest -Force
  Remove-Item -Recurse -Force "$dest\temp", "$dest\templates.zip"
  ```

---

### 2. Export for Windows (.exe Standalone)

The `Windows Desktop` preset in `export_presets.cfg` is configured with `binary_format/embed_pck=true`, bundling all game data directly into the executable.

```powershell
# Create output directory
New-Item -ItemType Directory -Force -Path dist | Out-Null

# Export standalone executable
godot_console.exe --headless --path . --export-release "Windows Desktop" dist/les_cartes_magiques_godot.exe
```

The resulting standalone executable `dist/les_cartes_magiques_godot.exe` can be distributed and launched without external dependencies.

---

### 3. Export for Android (.apk & .aab)

#### Android Prerequisites:
1. **Android SDK & Command-line Tools:** Android SDK platforms 33/34 and build-tools installed via Android Studio or command-line tools.
2. **OpenJDK 17:** Installed and configured in `PATH` / `JAVA_HOME`.
3. **Signing Keystores:**
   * **For Debug:**
     ```powershell
     keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999
     ```
   * **For Release:** `scripts/build_aab.py` automatically provisions `output/keystores/release.keystore`.

#### Build Standalone APK (Direct Install / Sideloading / Debugging):
The `Android APK` preset targets `arm64-v8a` by default for a lean, optimized binary (~158 MB).
```powershell
godot_console.exe --headless --path . --export-release "Android APK" dist/les_cartes_magiques.apk
```
Install directly to a USB-connected Android device or emulator:
```powershell
adb install -r dist/les_cartes_magiques.apk
```

#### Build Android App Bundle (.aab for Google Play Store):
```powershell
python scripts/build_aab.py
```
The optimized release bundle (~109 MB) is automatically built and staged into `play_store_assets/les_cartes_magiques.aab`.

---

### 4. Export for iOS (.ipa / Xcode Project)

Building for iOS requires a macOS machine with Xcode:
```bash
# Generate full Xcode project in dist/ios/
mkdir -p dist/ios
godot --headless --path . --export-release "iOS" dist/ios/les_cartes_magiques.ipa
```
Open the generated project in Xcode to sign it with your Apple Developer account and deploy to iPhone/iPad devices.

---

## 🗜️ Package Size Optimization & Master Asset Preservation

The project employs a targeted size-reduction strategy that minimizes mobile download and installation footprints without compromising visual or acoustic quality.

### 1. Optimization Summary

| Component | Before | After | Savings | Strategy & Settings |
| :--- | :--- | :--- | :--- | :--- |
| **Reward Videos (`.ogv`)** | 58.7 MB | **58.7 MB** | **0 MB (Preserved)** | **Native quality preserved:** Theora re-compression is skipped to prevent color fringing and macroblock artifacts on 2D animations. |
| **Voice Clips (`.mp3`)** | 62.5 MB | **21.3 MB** | **-41.2 MB (-66%)** | 874 voice clips re-encoded to 64 kbps mono (transparent voice fidelity for speech). |
| **Export Sanitization (`tmp/*`)** | 6.2 MB | **0.0 MB** | **-6.2 MB (-100%)** | Work directories and test artifacts excluded in `export_presets.cfg`. |
| **Native Architecture (`.so`)** | 72.7 MB (3 ABIs) | **23.3 MB** | **-49.4 MB (-68%)** | Default `arm64-v8a` target in standalone APK (eliminates redundant 32-bit and x86 runtimes). |

### 2. High-Quality Master Preservation (`assets_original/`)

To guarantee that master audio and video source files are never lost:
* **Master Location:** All pristine source audio and video files are archived in `assets_original/` (`assets_original/videos/` and `assets_original/audio/`).
* **Godot Scanner Protection via `.gdignore`:** The file `assets_original/.gdignore` instructs Godot's asset scanner and exporter to completely ignore this directory during editor imports and packaging.
* **Automated Optimization Pipeline:** If new voice clips are generated (via `generate_all_audio.py` or `tts_generator.py`), the optimization pipeline can be re-run with:
  ```powershell
  python scripts/optimize_assets.py
  ```

---

## 🐍 Original Python Prototype
```powershell
pip install -r requirements.txt
python main.py
pytest -v
```
