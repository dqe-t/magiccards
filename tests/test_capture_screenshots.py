"""Unit tests for screenshot automation and reporting pipeline."""

from pathlib import Path
import pytest

from scripts.capture_screenshots import (
    DeviceFormat,
    ScreenType,
    build_godot_capture_command,
    generate_markdown_report,
    run_godot_capture,
    verify_screenshots,
)


SAMPLE_DEVICES: list[DeviceFormat] = [
    DeviceFormat(
        device_id="test_dev_a",
        display_name="Test Device A",
        resolution="1920x1080",
        aspect_ratio="16:9",
        dpi=96,
        diag_inches=24.0,
        description="Test desktop device.",
    ),
    DeviceFormat(
        device_id="test_dev_b",
        display_name="Test Device B",
        resolution="1280x800",
        aspect_ratio="16:10",
        dpi=160,
        diag_inches=10.0,
        description="Test tablet device.",
    ),
]

SAMPLE_SCREENS: list[ScreenType] = [
    ScreenType(screen_id="01_menu", title="Main Menu", description="Main menu test."),
    ScreenType(screen_id="02_game", title="Game View", description="Game view test."),
]


def test_happy_path_report_generation(tmp_path: Path) -> None:
    """Happy Path: Verifies markdown report creation and content structure."""
    output_dir = tmp_path / "screenshots"
    output_dir.mkdir(parents=True, exist_ok=True)

    for dev in SAMPLE_DEVICES:
        dev_dir = output_dir / dev.device_id
        dev_dir.mkdir(parents=True, exist_ok=True)
        for screen in SAMPLE_SCREENS:
            img_file = dev_dir / f"{screen.screen_id}.png"
            img_file.write_bytes(b"\x89PNG\r\n\x1a\nfakeimagebytes")

    verified_files = verify_screenshots(output_dir, SAMPLE_DEVICES, SAMPLE_SCREENS)
    assert len(verified_files) == 4

    report_file = tmp_path / "device_report.md"
    result_path = generate_markdown_report(output_dir, SAMPLE_DEVICES, SAMPLE_SCREENS, report_file)

    assert result_path.exists()
    content = result_path.read_text(encoding="utf-8")
    assert "Test Device A" in content
    assert "Test Device B" in content
    assert "01_menu" in content
    assert "02_game" in content


def test_failure_path_missing_screenshots(tmp_path: Path) -> None:
    """Failure Path 1: Raises FileNotFoundError when expected images are missing."""
    output_dir = tmp_path / "screenshots"
    output_dir.mkdir(parents=True, exist_ok=True)

    dev_dir = output_dir / SAMPLE_DEVICES[0].device_id
    dev_dir.mkdir(parents=True, exist_ok=True)
    (dev_dir / f"{SAMPLE_SCREENS[0].screen_id}.png").write_bytes(b"data")

    with pytest.raises(FileNotFoundError, match="expected screenshot\\(s\\) were missing"):
        verify_screenshots(output_dir, SAMPLE_DEVICES, SAMPLE_SCREENS)


def test_failure_path_empty_screenshot_file(tmp_path: Path) -> None:
    """Failure Path 2: Raises FileNotFoundError when a screenshot exists but is 0 bytes."""
    output_dir = tmp_path / "screenshots"
    output_dir.mkdir(parents=True, exist_ok=True)

    for dev in SAMPLE_DEVICES:
        dev_dir = output_dir / dev.device_id
        dev_dir.mkdir(parents=True, exist_ok=True)
        for screen in SAMPLE_SCREENS:
            img_file = dev_dir / f"{screen.screen_id}.png"
            img_file.write_bytes(b"")

    with pytest.raises(FileNotFoundError, match="empty file"):
        verify_screenshots(output_dir, SAMPLE_DEVICES, SAMPLE_SCREENS)


def test_failure_path_invalid_godot_binary(tmp_path: Path) -> None:
    """Failure Path 3: Raises FileNotFoundError when an invalid Godot binary path is passed."""
    non_existent_binary = tmp_path / "missing_godot_executable.exe"
    with pytest.raises(FileNotFoundError, match="Godot binary not found"):
        run_godot_capture(non_existent_binary, tmp_path)


def test_godot_command_disables_audio(tmp_path: Path) -> None:
    """Happy Path: Verifies that screenshot command strictly disables audio output."""
    godot_bin = tmp_path / "godot_console.exe"
    cmd = build_godot_capture_command(godot_bin, tmp_path)
    assert "--audio-driver" in cmd
    idx = cmd.index("--audio-driver")
    assert cmd[idx + 1] == "Dummy"
