"""Android App Bundle (.aab) generation script for Les Cartes Magiques.

Automates environment checks, release keystore provisioning, Godot Gradle export,
and mirroring of the final artifact into play_store_assets/.
"""

import os
from pathlib import Path
import shutil
import subprocess
import sys


def resolve_android_sdk(custom_path: str | None = None) -> Path:
    """Resolve and validate the Android SDK directory path.

    Raises:
        FileNotFoundError: If Android SDK directory is missing or invalid.
    """
    if custom_path:
        candidate = Path(custom_path)
        if candidate.is_dir() and (candidate / "platforms").is_dir():
            return candidate.resolve()
        raise FileNotFoundError(f"Specified Android SDK directory is invalid: {custom_path}")

    candidates: list[Path] = []
    if os.environ.get("ANDROID_HOME"):
        candidates.append(Path(os.environ["ANDROID_HOME"]))
    if os.environ.get("ANDROID_SDK_ROOT"):
        candidates.append(Path(os.environ["ANDROID_SDK_ROOT"]))

    user_home = Path.home()
    candidates.append(user_home / "AppData" / "Local" / "Android" / "Sdk")

    for candidate in candidates:
        if candidate.is_dir() and (candidate / "platforms").is_dir():
            return candidate.resolve()

    raise FileNotFoundError(
        "CRITICAL: Android SDK directory not found. Please set ANDROID_HOME."
    )


def resolve_java_home(custom_path: str | None = None) -> Path:
    """Resolve and validate the Java SDK 17+ directory path.

    Raises:
        FileNotFoundError: If Java home directory or keytool binary is missing.
    """
    if custom_path:
        candidate = Path(custom_path)
        keytool_exe = candidate / "bin" / ("keytool.exe" if sys.platform == "win32" else "keytool")
        if candidate.is_dir() and keytool_exe.is_file():
            return candidate.resolve()
        raise FileNotFoundError(f"Specified Java home directory is invalid: {custom_path}")

    candidates: list[Path] = []
    if os.environ.get("JAVA_HOME"):
        candidates.append(Path(os.environ["JAVA_HOME"]))

    candidates.append(Path(r"C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot"))

    for candidate in candidates:
        keytool_exe = candidate / "bin" / ("keytool.exe" if sys.platform == "win32" else "keytool")
        if candidate.is_dir() and keytool_exe.is_file():
            return candidate.resolve()

    raise FileNotFoundError(
        "CRITICAL: JDK directory with keytool not found. Please set JAVA_HOME."
    )


def resolve_godot_binary(custom_path: str | None = None) -> Path:
    """Resolve Godot executable path.

    Raises:
        FileNotFoundError: If Godot console binary is not found.
    """
    if custom_path:
        path = Path(custom_path)
        if path.is_file():
            return path.resolve()
        raise FileNotFoundError(f"Specified Godot binary does not exist: {custom_path}")

    for cmd in ["godot_console.exe", "godot.exe", "godot"]:
        found = shutil.which(cmd)
        if found:
            return Path(found).resolve()

    local_app_data = Path(os.environ.get("LOCALAPPDATA", ""))
    winget_link = local_app_data / "Microsoft" / "WinGet" / "Links" / "godot_console.exe"
    if winget_link.is_file():
        return winget_link.resolve()

    raise FileNotFoundError("CRITICAL: Godot executable not found in PATH.")


def ensure_release_keystore(
    keystore_path: Path,
    alias: str,
    password: str,
    java_home: Path,
) -> Path:
    """Ensure release keystore exists, generating a 2048-bit RSA key if absent.

    Raises:
        ValueError: If alias or password is empty.
        RuntimeError: If keytool command fails.
    """
    if not alias:
        raise ValueError("CRITICAL: Keystore alias is required.")
    if not password:
        raise ValueError("CRITICAL: Keystore password is required.")

    if keystore_path.is_file() and keystore_path.stat().st_size > 0:
        return keystore_path.resolve()

    keystore_path.parent.mkdir(parents=True, exist_ok=True)
    keytool_bin = java_home / "bin" / ("keytool.exe" if sys.platform == "win32" else "keytool")

    cmd = [
        str(keytool_bin),
        "-genkeypair",
        "-v",
        "-keystore",
        str(keystore_path),
        "-alias",
        alias,
        "-keyalg",
        "RSA",
        "-keysize",
        "2048",
        "-validity",
        "10000",
        "-storepass",
        password,
        "-keypass",
        password,
        "-dname",
        "CN=Les Cartes Magiques, OU=Release, O=La Roulette Magique, L=Paris, ST=IDF, C=FR",
    ]

    res = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if res.returncode != 0:
        raise RuntimeError(f"keytool failed:\n{res.stderr}\n{res.stdout}")

    return keystore_path.resolve()


def export_aab(
    project_dir: Path,
    output_aab: Path,
    godot_bin: Path,
    java_home: Path,
    android_sdk: Path,
) -> Path:
    """Execute Godot headless release export to generate the Android App Bundle (.aab).

    Raises:
        RuntimeError: If export process returns non-zero or output .aab is missing/empty.
    """
    output_aab.parent.mkdir(parents=True, exist_ok=True)
    if output_aab.is_file():
        output_aab.unlink()

    env = os.environ.copy()
    env["ANDROID_HOME"] = str(android_sdk)
    env["JAVA_HOME"] = str(java_home)
    env["GRADLE_OPTS"] = "-Dorg.gradle.daemon=false"
    env["PATH"] = f"{java_home / 'bin'}{os.pathsep}{env.get('PATH', '')}"

    cmd = [
        str(godot_bin),
        "--headless",
        "--path",
        str(project_dir),
        "--export-release",
        "Android",
        str(output_aab),
    ]

    try:
        proc = subprocess.run(cmd, env=env, capture_output=True, text=True, check=False)
        if proc.returncode != 0 or not output_aab.is_file() or output_aab.stat().st_size == 0:
            raise RuntimeError(
                f"Godot AAB export failed (code {proc.returncode}):\n{proc.stderr}\n{proc.stdout}"
            )
    finally:
        gradlew_bat = project_dir / "android" / "build" / ("gradlew.bat" if sys.platform == "win32" else "gradlew")
        if gradlew_bat.is_file():
            subprocess.run([str(gradlew_bat), "--stop"], cwd=str(project_dir / "android" / "build"), env=env, capture_output=True, check=False)

    return output_aab.resolve()


def mirror_to_play_store_assets(source_aab: Path, target_dir: Path) -> Path:
    """Mirror generated .aab into the play_store_assets/ folder.

    Raises:
        FileNotFoundError: If source_aab does not exist or is empty.
    """
    if not source_aab.is_file() or source_aab.stat().st_size == 0:
        raise FileNotFoundError(f"Cannot mirror missing or empty bundle: {source_aab}")

    target_dir.mkdir(parents=True, exist_ok=True)
    destination = target_dir / source_aab.name
    shutil.copy2(source_aab, destination)
    return destination.resolve()


def build_android_bundle() -> Path:
    """Orchestrate the full AAB build and asset delivery pipeline."""
    project_dir = Path(__file__).resolve().parent.parent
    android_sdk = resolve_android_sdk()
    java_home = resolve_java_home()
    godot_bin = resolve_godot_binary()

    keystore_path = project_dir / "output" / "keystores" / "release.keystore"
    ensure_release_keystore(
        keystore_path=keystore_path,
        alias="cartes_magiques",
        password="cartesmagiques",
        java_home=java_home,
    )

    output_aab = project_dir / "dist" / "les_cartes_magiques.aab"
    export_aab(
        project_dir=project_dir,
        output_aab=output_aab,
        godot_bin=godot_bin,
        java_home=java_home,
        android_sdk=android_sdk,
    )

    play_store_dir = project_dir / "play_store_assets"
    staged_aab = mirror_to_play_store_assets(output_aab, play_store_dir)
    return staged_aab


if __name__ == "__main__":
    result = build_android_bundle()
    print(f"Android App Bundle successfully generated and staged: {result}")
