"""Automated device screenshot runner and markdown report generator.

Generates high-resolution screenshots across multiple device form factors
(desktop, tablets, phones, phablet, ultrawide) and compiles an inspection
markdown document.
"""

from dataclasses import dataclass
from pathlib import Path
import shutil
import subprocess
import sys


@dataclass(frozen=True)
class DeviceFormat:
    device_id: str
    display_name: str
    resolution: str
    aspect_ratio: str
    dpi: int
    diag_inches: float
    description: str


@dataclass(frozen=True)
class ScreenType:
    screen_id: str
    title: str
    description: str


SUPPORTED_DEVICES: list[DeviceFormat] = [
    DeviceFormat(
        device_id="desktop_27in",
        display_name="27-inch Desktop Monitor",
        resolution="1920x1080",
        aspect_ratio="16:9",
        dpi=82,
        diag_inches=27.0,
        description="Standard 1080p desktop with physical card size ceiling.",
    ),
    DeviceFormat(
        device_id="tablet_10in",
        display_name="10.1-inch Android Tablet",
        resolution="1920x1200",
        aspect_ratio="16:10",
        dpi=224,
        diag_inches=10.1,
        description="Target family tablet display with 2-row letter configuration.",
    ),
    DeviceFormat(
        device_id="phone_6in",
        display_name="6.0-inch Smartphone",
        resolution="2340x1080",
        aspect_ratio="19.5:9",
        dpi=430,
        diag_inches=6.0,
        description="Modern tall aspect ratio smartphone in landscape orientation.",
    ),
    DeviceFormat(
        device_id="phone_7in",
        display_name="7.0-inch Large Phone / Phablet",
        resolution="2400x1080",
        aspect_ratio="20:9",
        dpi=375,
        diag_inches=7.0,
        description="Ultra-wide phone/foldable display with extended horizontal canvas.",
    ),
    DeviceFormat(
        device_id="tablet_ipad_11in",
        display_name="11.0-inch iPad / Tablet",
        resolution="2048x1536",
        aspect_ratio="4:3",
        dpi=264,
        diag_inches=11.0,
        description="Square-leaning tablet aspect ratio testing vertical margins.",
    ),
    DeviceFormat(
        device_id="laptop_15in",
        display_name="15.6-inch Laptop",
        resolution="1920x1080",
        aspect_ratio="16:9",
        dpi=141,
        diag_inches=15.6,
        description="Standard mid-size laptop display with moderate pixel density.",
    ),
    DeviceFormat(
        device_id="ultrawide_34in",
        display_name="34.0-inch Ultra-Wide Monitor",
        resolution="2560x1080",
        aspect_ratio="21:9",
        dpi=82,
        diag_inches=34.0,
        description="Panoramic 21:9 monitor testing extreme aspect ratio card distribution.",
    ),
    DeviceFormat(
        device_id="phone_compact_5in",
        display_name="5.0-inch Compact Phone",
        resolution="1280x720",
        aspect_ratio="16:9",
        dpi=294,
        diag_inches=5.0,
        description="Entry-level compact phone testing minimal viewport density.",
    ),
]

SCREEN_TYPES: list[ScreenType] = [
    ScreenType("01_main_menu", "Main Menu", "Main menu with title and primary actions."),
    ScreenType("02_config_screen", "Configuration Screen", "Profile management and symbol selector grid."),
    ScreenType("03_gameplay_3cards", "Gameplay (3 Cards)", "Active prompt with 3 dealt cards and star bar."),
    ScreenType("04_gameplay_5cards", "Gameplay (5 Cards)", "Maximum density round showing 5 simultaneous cards."),
    ScreenType("05_gameplay_solved", "Gameplay (Celebration)", "Correct answer feedback with rainbow card effects."),
    ScreenType("06_score_screen", "Score & Reward Screen", "Completed round showing 10 golden stars and animal award."),
]


def find_godot_executable() -> Path:
    """Locate the godot_console or godot binary in PATH or common project paths."""
    for binary_name in ("godot_console.exe", "godot.exe", "godot_console", "godot"):
        found = shutil.which(binary_name)
        if found:
            return Path(found).resolve()
    raise FileNotFoundError("CRITICAL: Godot executable not found in system PATH.")


def build_godot_capture_command(godot_path: Path, project_root: Path) -> list[str]:
    """Construct command-line arguments for screenshot capture with sound disabled."""
    return [
        str(godot_path),
        "--windowed",
        "--resolution",
        "640x480",
        "--audio-driver",
        "Dummy",
        "--path",
        str(project_root),
        "-s",
        "res://scripts/generate_device_screenshots.gd",
    ]


def run_godot_capture(godot_path: Path, project_root: Path) -> None:
    """Execute Godot screenshot generation script in total silence."""
    if not godot_path.exists():
        raise FileNotFoundError(f"CRITICAL: Godot binary not found at '{godot_path}'.")
    if not project_root.exists():
        raise FileNotFoundError(f"CRITICAL: Project root not found at '{project_root}'.")

    script_path = project_root / "scripts" / "generate_device_screenshots.gd"
    if not script_path.exists():
        raise FileNotFoundError(f"CRITICAL: Script missing at '{script_path}'.")

    cmd = build_godot_capture_command(godot_path, project_root)
    result = subprocess.run(cmd, cwd=str(project_root), capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(
            f"Godot screenshot generation failed (code {result.returncode}):\n{result.stderr}\n{result.stdout}"
        )


def verify_screenshots(output_dir: Path, devices: list[DeviceFormat], screens: list[ScreenType]) -> list[Path]:
    """Verify all expected screenshot files exist and are non-empty."""
    if not output_dir.exists():
        raise FileNotFoundError(f"CRITICAL: Output directory does not exist: '{output_dir}'.")

    verified_files: list[Path] = []
    missing_files: list[str] = []

    for device in devices:
        device_folder = output_dir / device.device_id
        for screen in screens:
            file_path = device_folder / f"{screen.screen_id}.png"
            if not file_path.exists():
                missing_files.append(str(file_path))
            elif file_path.stat().st_size == 0:
                missing_files.append(f"{file_path} (empty file)")
            else:
                verified_files.append(file_path)

    if missing_files:
        raise FileNotFoundError(
            f"CRITICAL: {len(missing_files)} expected screenshot(s) were missing or empty:\n"
            + "\n".join(missing_files[:10])
        )

    return verified_files


def generate_markdown_report(
    output_dir: Path,
    devices: list[DeviceFormat],
    screens: list[ScreenType],
    report_path: Path,
) -> Path:
    """Generate master markdown report linking all screenshots organized by screen and device."""
    if not output_dir.exists():
        raise FileNotFoundError(f"CRITICAL: Output directory missing: '{output_dir}'.")

    report_path.parent.mkdir(parents=True, exist_ok=True)
    lines: list[str] = [
        "# 🎡 La Roulette Magique - Automated Multi-Screen Test Matrix",
        "",
        "> **Automated Layout & Visual Verification Report**",
        f"> *Total Device Form Factors:* **{len(devices)}** | *Screens Evaluated:* **{len(screens)}** | *Total Screenshots:* **{len(devices) * len(screens)}**",
        "",
        "---",
        "",
        "## 📱 Evaluated Device Form Factors",
        "",
        "| Form Factor | Display Name | Resolution | Ratio | Screen Diagonal | Effective PPI | Target Behavior |",
        "| :--- | :--- | :--- | :--- | :--- | :--- | :--- |",
    ]

    for d in devices:
        lines.append(
            f"| `{d.device_id}` | **{d.display_name}** | `{d.resolution}` | `{d.aspect_ratio}` | `{d.diag_inches}\"` | `{d.dpi}` | {d.description} |"
        )

    lines.extend([
        "",
        "---",
        "",
        "## 📸 Comprehensive Visual Matrix",
        "",
    ])

    for screen in screens:
        lines.extend([
            f"### Screen: {screen.title} (`{screen.screen_id}`)",
            f"*{screen.description}*",
            "",
        ])

        for dev in devices:
            rel_image_path = f"screenshots/{dev.device_id}/{screen.screen_id}.png"
            lines.extend([
                f"#### {dev.display_name} (`{dev.resolution}` • `{dev.diag_inches}\"` • `{dev.aspect_ratio}`)",
                f"![{screen.title} - {dev.display_name}]({rel_image_path})",
                "",
            ])

        lines.append("---")
        lines.append("")

    report_path.write_text("\n".join(lines), encoding="utf-8")
    return report_path


def main() -> int:
    """CLI Entrypoint for screenshot automation."""
    project_root = Path(__file__).resolve().parent.parent
    output_dir = project_root / "output" / "screenshots"
    report_path = project_root / "output" / "device_screenshots_report.md"

    output_dir.mkdir(parents=True, exist_ok=True)
    godot_bin = find_godot_executable()

    print(f"[INFO] Using Godot binary: {godot_bin}")
    print("[INFO] Generating device screenshots via Godot...")
    run_godot_capture(godot_bin, project_root)

    print("[INFO] Verifying generated images...")
    verified = verify_screenshots(output_dir, SUPPORTED_DEVICES, SCREEN_TYPES)
    print(f"[INFO] Verified {len(verified)} screenshots.")

    print(f"[INFO] Compiling markdown report: {report_path}")
    generate_markdown_report(output_dir, SUPPORTED_DEVICES, SCREEN_TYPES, report_path)
    print("[SUCCESS] All screenshots and report generated successfully.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
