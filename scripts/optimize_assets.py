"""Asset optimization and high-quality backup pipeline for La Roulette Magique.

Automates:
1. Preserving pristine high-quality original assets in assets_original/.
2. Re-encoding reward videos (.ogv) with FFmpeg libtheora at optimal quality.
3. Re-encoding speech audio (.mp3) with FFmpeg at 64k mono.
"""

from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
import os
from pathlib import Path
import shutil
import subprocess


@dataclass(frozen=True)
class OptimizationSummary:
    """Summary of asset backup and optimization results."""

    backed_up_count: int
    videos_optimized: int
    audio_optimized: int
    saved_bytes: int


def resolve_ffmpeg_binary() -> Path:
    """Resolve ffmpeg binary from system PATH.

    Raises:
        FileNotFoundError: If ffmpeg is not found on PATH.
    """
    cmd = "ffmpeg.exe" if os.name == "nt" else "ffmpeg"
    found = shutil.which(cmd)
    if not found:
        raise FileNotFoundError("CRITICAL: FFmpeg binary not found on system PATH.")
    return Path(found).resolve()


def backup_originals(source_dir: Path, backup_dir: Path) -> int:
    """Backup media files from source_dir into backup_dir preserving structure.

    Raises:
        FileNotFoundError: If source_dir does not exist.
    """
    if not source_dir.is_dir():
        raise FileNotFoundError(f"Source media directory not found: {source_dir}")

    backup_dir.mkdir(parents=True, exist_ok=True)
    gdignore = backup_dir / ".gdignore"
    if not gdignore.is_file():
        gdignore.write_text("# Tell Godot to ignore original media assets\n", encoding="utf-8")

    copied_count: int = 0
    for root, _, files in os.walk(source_dir):
        rel_root = Path(root).relative_to(source_dir)
        for f in files:
            ext = os.path.splitext(f)[1].lower()
            if ext in [".ogv", ".mp3", ".wav"]:
                src_file = Path(root) / f
                dst_file = backup_dir / rel_root / f
                if not dst_file.is_file():
                    dst_file.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src_file, dst_file)
                    copied_count += 1

    return copied_count


def optimize_video_file(
    input_file: Path,
    output_file: Path,
    ffmpeg_bin: Path,
    quality: int = 5,
) -> None:
    """Re-encode a single Theora video using FFmpeg.

    Raises:
        FileNotFoundError: If input_file or ffmpeg_bin does not exist.
        ValueError: If quality is outside 0..10.
        RuntimeError: If FFmpeg encoding command fails.
    """
    if not input_file.is_file():
        raise FileNotFoundError(f"Input video file not found: {input_file}")
    if not ffmpeg_bin.is_file():
        raise FileNotFoundError(f"FFmpeg binary not found: {ffmpeg_bin}")
    if not 0 <= quality <= 10:
        raise ValueError(f"Theora quality must be between 0 and 10, got {quality}")

    output_file.parent.mkdir(parents=True, exist_ok=True)
    cmd: list[str] = [
        str(ffmpeg_bin),
        "-y",
        "-i",
        str(input_file),
        "-c:v",
        "libtheora",
        "-q:v",
        str(quality),
        "-c:a",
        "copy",
        str(output_file),
    ]

    res = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if res.returncode != 0 or not output_file.is_file() or output_file.stat().st_size == 0:
        raise RuntimeError(f"FFmpeg video optimization failed for {input_file}:\n{res.stderr}")


def optimize_audio_file(
    input_file: Path,
    output_file: Path,
    ffmpeg_bin: Path,
    bitrate: str = "64k",
) -> None:
    """Re-encode a single speech MP3 file to mono at target bitrate.

    Raises:
        FileNotFoundError: If input_file or ffmpeg_bin does not exist.
        ValueError: If bitrate is empty.
        RuntimeError: If FFmpeg encoding command fails.
    """
    if not input_file.is_file():
        raise FileNotFoundError(f"Input audio file not found: {input_file}")
    if not ffmpeg_bin.is_file():
        raise FileNotFoundError(f"FFmpeg binary not found: {ffmpeg_bin}")
    if not bitrate:
        raise ValueError("Audio bitrate string must not be empty.")

    output_file.parent.mkdir(parents=True, exist_ok=True)
    cmd: list[str] = [
        str(ffmpeg_bin),
        "-y",
        "-i",
        str(input_file),
        "-b:a",
        bitrate,
        "-ac",
        "1",
        str(output_file),
    ]

    res = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if res.returncode != 0 or not output_file.is_file() or output_file.stat().st_size == 0:
        raise RuntimeError(f"FFmpeg audio optimization failed for {input_file}:\n{res.stderr}")


def optimize_all_videos(
    video_dir: Path,
    ffmpeg_bin: Path,
    quality: int = 5,
    max_workers: int = 4,
) -> int:
    """Optimize all .ogv videos in video_dir in-place.

    Raises:
        FileNotFoundError: If video_dir does not exist.
    """
    if not video_dir.is_dir():
        raise FileNotFoundError(f"Video directory not found: {video_dir}")

    video_files: list[Path] = sorted(video_dir.glob("*.ogv"))
    if not video_files:
        return 0

    def _worker(file_path: Path) -> None:
        tmp_target = file_path.with_suffix(".tmp.ogv")
        optimize_video_file(file_path, tmp_target, ffmpeg_bin, quality=quality)
        tmp_target.replace(file_path)

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        list(executor.map(_worker, video_files))

    return len(video_files)


def optimize_all_audio(
    audio_dir: Path,
    ffmpeg_bin: Path,
    bitrate: str = "64k",
    max_workers: int = 8,
) -> int:
    """Optimize all .mp3 voice clips in audio_dir in-place.

    Raises:
        FileNotFoundError: If audio_dir does not exist.
    """
    if not audio_dir.is_dir():
        raise FileNotFoundError(f"Audio directory not found: {audio_dir}")

    audio_files: list[Path] = sorted(audio_dir.rglob("*.mp3"))
    if not audio_files:
        return 0

    def _worker(file_path: Path) -> None:
        tmp_target = file_path.with_suffix(".tmp.mp3")
        optimize_audio_file(file_path, tmp_target, ffmpeg_bin, bitrate=bitrate)
        tmp_target.replace(file_path)

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        list(executor.map(_worker, audio_files))

    return len(audio_files)


def run_pipeline(
    project_dir: Path,
    optimize_videos: bool = False,
    audio_bitrate: str = "64k",
) -> OptimizationSummary:
    """Execute complete backup and media optimization pipeline.

    Args:
        project_dir: Root project directory.
        optimize_videos: Whether to re-encode videos. Defaults to False to
            preserve original pristine visual quality without Theora artifacts.
        audio_bitrate: Target bitrate for audio speech re-encoding.

    Raises:
        FileNotFoundError: If required directories or tools are missing.
    """
    ffmpeg_bin = resolve_ffmpeg_binary()
    assets_dir = project_dir / "assets"
    backup_dir = project_dir / "assets_original"

    if not assets_dir.is_dir():
        raise FileNotFoundError(f"Assets directory not found: {assets_dir}")

    # Calculate initial size
    initial_bytes: int = sum(
        f.stat().st_size
        for f in assets_dir.rglob("*")
        if f.is_file() and f.suffix.lower() in [".ogv", ".mp3"]
    )

    # 1. Backup pristine media
    backed_up: int = backup_originals(source_dir=assets_dir, backup_dir=backup_dir)

    # 2. Optimize videos (skipped by default to avoid visual artifacts)
    video_dir = assets_dir / "videos" / "animals"
    v_count: int = 0
    if optimize_videos and video_dir.is_dir():
        v_count = optimize_all_videos(video_dir=video_dir, ffmpeg_bin=ffmpeg_bin, quality=5)

    # 3. Optimize audio (voice speech is transparently encoded at 64k)
    audio_dir = assets_dir / "audio"
    a_count: int = 0
    if audio_dir.is_dir():
        a_count = optimize_all_audio(audio_dir=audio_dir, ffmpeg_bin=ffmpeg_bin, bitrate=audio_bitrate)

    # Calculate final size
    final_bytes: int = sum(
        f.stat().st_size
        for f in assets_dir.rglob("*")
        if f.is_file() and f.suffix.lower() in [".ogv", ".mp3"]
    )

    saved_bytes: int = max(0, initial_bytes - final_bytes)

    return OptimizationSummary(
        backed_up_count=backed_up,
        videos_optimized=v_count,
        audio_optimized=a_count,
        saved_bytes=saved_bytes,
    )


if __name__ == "__main__":
    root_path = Path(__file__).resolve().parent.parent
    summary = run_pipeline(root_path)
    print(
        f"Optimization complete:\n"
        f"  Backed up files: {summary.backed_up_count}\n"
        f"  Videos optimized: {summary.videos_optimized}\n"
        f"  Audio files optimized: {summary.audio_optimized}\n"
        f"  Disk space saved: {summary.saved_bytes / 1024 / 1024:.2f} MB"
    )
