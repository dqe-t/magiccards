"""Unit tests for scripts/build_aab.py."""

from pathlib import Path
import pytest

from scripts.build_aab import (
    ensure_release_keystore,
    mirror_to_play_store_assets,
    resolve_android_sdk,
    resolve_godot_binary,
    resolve_java_home,
)


def test_resolve_paths_happy_path() -> None:
    """Happy path: successfully resolve Android SDK, Java home, and Godot binary."""
    sdk = resolve_android_sdk()
    assert sdk.is_dir()
    assert (sdk / "platforms").is_dir()

    java = resolve_java_home()
    assert java.is_dir()

    godot = resolve_godot_binary()
    assert godot.is_file()


def test_resolve_android_sdk_invalid_path_failure(tmp_path: Path) -> None:
    """Failure path 1: invalid SDK path throws FileNotFoundError."""
    invalid_dir = tmp_path / "nonexistent_sdk"
    with pytest.raises(FileNotFoundError, match="Android SDK"):
        resolve_android_sdk(custom_path=str(invalid_dir))


def test_resolve_godot_binary_invalid_path_failure(tmp_path: Path) -> None:
    """Failure path 2: nonexistent Godot binary path throws FileNotFoundError."""
    invalid_bin = tmp_path / "missing_godot.exe"
    with pytest.raises(FileNotFoundError, match="Specified Godot binary does not exist"):
        resolve_godot_binary(custom_path=str(invalid_bin))


def test_ensure_release_keystore_empty_credentials_failure(tmp_path: Path) -> None:
    """Failure path 3: empty alias or password throws ValueError (fail-fast)."""
    keystore = tmp_path / "test.keystore"
    java = resolve_java_home()

    with pytest.raises(ValueError, match="Keystore alias is required"):
        ensure_release_keystore(keystore, alias="", password="pass", java_home=java)

    with pytest.raises(ValueError, match="Keystore password is required"):
        ensure_release_keystore(keystore, alias="alias", password="", java_home=java)


def test_mirror_to_play_store_assets_empty_or_missing_failure(tmp_path: Path) -> None:
    """Failure path 4: missing or empty source bundle throws FileNotFoundError."""
    missing_file = tmp_path / "missing.aab"
    target_dir = tmp_path / "out"

    with pytest.raises(FileNotFoundError, match="Cannot mirror missing or empty bundle"):
        mirror_to_play_store_assets(missing_file, target_dir)

    empty_file = tmp_path / "empty.aab"
    empty_file.write_bytes(b"")
    with pytest.raises(FileNotFoundError, match="Cannot mirror missing or empty bundle"):
        mirror_to_play_store_assets(empty_file, target_dir)


def test_mirror_to_play_store_assets_happy_path(tmp_path: Path) -> None:
    """Happy path: valid bundle file copied successfully to destination directory."""
    source_file = tmp_path / "valid.aab"
    source_file.write_bytes(b"PK\x03\x04mock_content_for_aab_bundle")
    target_dir = tmp_path / "target_store"

    staged = mirror_to_play_store_assets(source_file, target_dir)
    assert staged.is_file()
    assert staged.name == "valid.aab"
    assert staged.read_bytes() == b"PK\x03\x04mock_content_for_aab_bundle"
