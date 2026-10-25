"""Unit tests for the asset optimization and backup pipeline."""

from pathlib import Path
import subprocess
import pytest

from scripts.optimize_assets import (
    backup_originals,
    optimize_audio_file,
    optimize_video_file,
    resolve_ffmpeg_binary,
)


def test_backup_originals_happy_path(tmp_path: Path) -> None:
    """Test standard happy path for backing up original assets."""
    source_dir = tmp_path / "source"
    source_dir.mkdir()
    (source_dir / "test.ogv").write_bytes(b"dummy_video_bytes")
    sub_dir = source_dir / "sub"
    sub_dir.mkdir()
    (sub_dir / "speech.mp3").write_bytes(b"dummy_audio_bytes")
    (sub_dir / "ignore.txt").write_bytes(b"ignore_me")

    backup_dir = tmp_path / "backup"
    copied = backup_originals(source_dir, backup_dir)

    assert copied == 2
    assert (backup_dir / ".gdignore").is_file()
    assert (backup_dir / "test.ogv").is_file()
    assert (backup_dir / "sub" / "speech.mp3").is_file()
    assert not (backup_dir / "sub" / "ignore.txt").exists()


def test_backup_originals_raises_on_missing_source(tmp_path: Path) -> None:
    """Failure path 1: backup_originals raises FileNotFoundError if source is missing."""
    missing = tmp_path / "does_not_exist"
    backup = tmp_path / "backup"
    with pytest.raises(FileNotFoundError, match="Source media directory not found"):
        backup_originals(missing, backup)


def test_optimize_video_file_raises_on_missing_input(tmp_path: Path) -> None:
    """Failure path 2: optimize_video_file raises FileNotFoundError for missing file."""
    ffmpeg_bin = resolve_ffmpeg_binary()
    missing_file = tmp_path / "missing.ogv"
    out_file = tmp_path / "out.ogv"

    with pytest.raises(FileNotFoundError, match="Input video file not found"):
        optimize_video_file(missing_file, out_file, ffmpeg_bin, quality=5)


def test_optimize_video_file_raises_on_invalid_quality(tmp_path: Path) -> None:
    """Failure path 3: optimize_video_file raises ValueError for out-of-bounds quality."""
    ffmpeg_bin = resolve_ffmpeg_binary()
    dummy_input = tmp_path / "input.ogv"
    dummy_input.write_bytes(b"data")
    out_file = tmp_path / "out.ogv"

    with pytest.raises(ValueError, match="Theora quality must be between 0 and 10"):
        optimize_video_file(dummy_input, out_file, ffmpeg_bin, quality=99)


def test_optimize_audio_file_raises_on_empty_bitrate(tmp_path: Path) -> None:
    """Failure path 4: optimize_audio_file raises ValueError on empty bitrate."""
    ffmpeg_bin = resolve_ffmpeg_binary()
    dummy_input = tmp_path / "input.mp3"
    dummy_input.write_bytes(b"data")
    out_file = tmp_path / "out.mp3"

    with pytest.raises(ValueError, match="Audio bitrate string must not be empty"):
        optimize_audio_file(dummy_input, out_file, ffmpeg_bin, bitrate="")


def test_optimize_audio_file_happy_path(tmp_path: Path) -> None:
    """Happy path: Generate synthetic 0.5s audio and re-encode to 64k mono."""
    ffmpeg_bin = resolve_ffmpeg_binary()
    sample_src = tmp_path / "synth_192k.mp3"

    # Generate 0.5s sine tone at 192k stereo
    subprocess.run(
        [
            str(ffmpeg_bin),
            "-y",
            "-f",
            "lavfi",
            "-i",
            "sine=frequency=440:duration=0.5",
            "-b:a",
            "192k",
            str(sample_src),
        ],
        check=True,
        capture_output=True,
    )

    sample_out = tmp_path / "synth_64k.mp3"
    optimize_audio_file(sample_src, sample_out, ffmpeg_bin, bitrate="64k")

    assert sample_out.is_file()
    assert sample_out.stat().st_size > 0
    assert sample_out.stat().st_size < sample_src.stat().st_size
