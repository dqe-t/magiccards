import base64
import os
from pathlib import Path
import sys
from unittest.mock import MagicMock, patch
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from scripts.tts_generator import (
    TTSRequest,
    build_french_style_prompt,
    resolve_project_id,
    synthesize_speech,
    validate_french_style_prompt,
    validate_tts_request,
)


def test_synthesize_speech_happy_path(tmp_path: Path) -> None:
    output_mp3 = tmp_path / "voice.mp3"
    fake_wav_bytes = b"RIFFfake-wav-data"
    b64_audio = base64.b64encode(fake_wav_bytes).decode("ascii")

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "candidates": [
            {
                "content": {
                    "parts": [{"inlineData": {"data": b64_audio}}]
                }
            }
        ]
    }

    mock_creds = MagicMock()
    mock_creds.token = "fake-token"

    with patch("scripts.tts_generator.google.auth.default", return_value=(mock_creds, "mock-proj")):
        with patch("scripts.tts_generator.requests.post", return_value=mock_resp) as mock_post:
            with patch("scripts.tts_generator.subprocess.run") as mock_sub:
                mock_sub.return_value = MagicMock(returncode=0, stderr="")
                request = TTSRequest(
                    text="Bonjour !",
                    output_path=output_mp3,
                    voice_name="Aoede",
                    style_prompt="Joyeuse institutrice",
                    project_id="test-project",
                )
                result = synthesize_speech(request)
                assert result == output_mp3
                call_args = mock_post.call_args[1]
                assert call_args["json"]["generationConfig"]["speechConfig"]["voiceConfig"]["prebuiltVoiceConfig"]["voiceName"] == "Aoede"


def test_validate_tts_request_empty_text(tmp_path: Path) -> None:
    request = TTSRequest(
        text="   ",
        output_path=tmp_path / "out.mp3",
        voice_name="Aoede",
    )
    with pytest.raises(ValueError, match="CRITICAL: Input text cannot be empty"):
        validate_tts_request(request)


def test_validate_tts_request_invalid_extension(tmp_path: Path) -> None:
    request = TTSRequest(
        text="Bonjour",
        output_path=tmp_path / "out.wav",
        voice_name="Aoede",
    )
    with pytest.raises(ValueError, match="CRITICAL: Output path must have .mp3 extension"):
        validate_tts_request(request)


def test_synthesize_speech_api_error(tmp_path: Path) -> None:
    mock_resp = MagicMock()
    mock_resp.status_code = 500
    mock_resp.text = "Internal Server Error"

    mock_creds = MagicMock()
    mock_creds.token = "fake-token"

    with patch("scripts.tts_generator.google.auth.default", return_value=(mock_creds, "mock-proj")):
        with patch("scripts.tts_generator.requests.post", return_value=mock_resp):
            request = TTSRequest(
                text="Bonjour",
                output_path=tmp_path / "err.mp3",
                voice_name="Aoede",
                project_id="test-project",
            )
            with pytest.raises(RuntimeError, match="CRITICAL: Gemini 3.8 Flash TTS API error"):
                synthesize_speech(request)


def test_resolve_project_id_missing() -> None:
    with patch.dict(os.environ, {}, clear=True):
        with patch("scripts.tts_generator.google.auth.default", side_effect=Exception("no auth")):
            with patch("scripts.tts_generator.subprocess.run") as mock_sub:
                mock_sub.return_value = MagicMock(returncode=1, stdout="")
                with pytest.raises(ValueError, match="CRITICAL: Google Cloud Project ID is required"):
                    resolve_project_id(None)


def test_build_french_style_prompt_happy_path() -> None:
    res = build_french_style_prompt("Ton joyeux d'instituteur.")
    assert "Voix en français" in res
    assert "Prononciation française authentique et naturelle" in res
    assert "Ton joyeux d'instituteur." in res


def test_build_french_style_prompt_empty_failure() -> None:
    with pytest.raises(ValueError, match="CRITICAL: description must be a non-empty string"):
        build_french_style_prompt("   ")


def test_validate_french_style_prompt_happy_path() -> None:
    validate_french_style_prompt("Voix en français avec intonation joyeuse.")
    validate_french_style_prompt("Clear French accent, energetic.")


def test_validate_french_style_prompt_missing_language_failure() -> None:
    with pytest.raises(ValueError, match="CRITICAL: Style prompt must explicitly enforce French language"):
        validate_french_style_prompt("Warm preschool teacher imitating bear.")


def test_validate_french_style_prompt_empty_failure() -> None:
    with pytest.raises(ValueError, match="CRITICAL: style_prompt must be a non-empty string"):
        validate_french_style_prompt("")

