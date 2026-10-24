import base64
from dataclasses import dataclass
import json
import os
from pathlib import Path
import shutil
import subprocess
from typing import Literal

import google.auth
from google.auth.transport.requests import Request
import requests

VoiceGenderType = Literal["FEMALE", "MALE"]


@dataclass(frozen=True)
class TTSRequest:
    text: str
    output_path: Path
    voice_name: str
    style_prompt: str | None = None
    model_name: str = "gemini-3.8-flash-tts"
    project_id: str | None = None
    bitrate: str = "192k"
    sample_rate: int = 44100


def build_french_style_prompt(description: str) -> str:
    """Build a standardized style prompt that strictly enforces French pronunciation."""
    if not isinstance(description, str) or not description.strip():
        raise ValueError("CRITICAL: description must be a non-empty string.")
    return f"Voix en français. Prononciation française authentique et naturelle. {description.strip()}"


def validate_french_style_prompt(style_prompt: str) -> None:
    """Ensure style prompt explicitly requires French language phonetics to prevent American loanword pronunciation."""
    if not isinstance(style_prompt, str) or not style_prompt.strip():
        raise ValueError("CRITICAL: style_prompt must be a non-empty string.")
    lower = style_prompt.lower()
    if "français" not in lower and "french" not in lower:
        raise ValueError(
            "CRITICAL: Style prompt must explicitly enforce French language "
            "('français' or 'French') to prevent American/English phonetics on loanwords."
        )


def resolve_project_id(explicit_project: str | None = None) -> str:
    if explicit_project is not None and explicit_project.strip():
        return explicit_project.strip()

    for env_var in ("GOOGLE_CLOUD_PROJECT", "GCP_PROJECT", "PROJECT_ID"):
        val = os.environ.get(env_var)
        if val is not None and val.strip():
            return val.strip()

    try:
        _, auth_proj = google.auth.default()
        if auth_proj is not None and auth_proj.strip():
            return auth_proj.strip()
    except Exception:
        pass

    cred_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if cred_path is not None and Path(cred_path).is_file():
        try:
            data = json.loads(Path(cred_path).read_text(encoding="utf-8"))
            if "project_id" in data and str(data["project_id"]).strip():
                return str(data["project_id"]).strip()
        except Exception:
            pass

    gcloud_bin = shutil.which("gcloud") or shutil.which("gcloud.cmd") or "gcloud"
    try:
        res = subprocess.run(
            [gcloud_bin, "config", "get-value", "project"],
            capture_output=True,
            text=True,
            check=False,
            shell=True if os.name == "nt" else False,
        )
        if res.returncode == 0 and res.stdout.strip() and "(unset)" not in res.stdout:
            return res.stdout.strip()
    except Exception:
        pass

    raise ValueError("CRITICAL: Google Cloud Project ID is required for Gemini 3.8 Flash TTS.")


def validate_tts_request(request: TTSRequest) -> None:
    if not request.text or not request.text.strip():
        raise ValueError("CRITICAL: Input text cannot be empty or whitespace.")

    if request.output_path.suffix.lower() != ".mp3":
        raise ValueError(
            f"CRITICAL: Output path must have .mp3 extension, got '{request.output_path.suffix}'."
        )

    if not request.voice_name or not request.voice_name.strip():
        raise ValueError("CRITICAL: voice_name cannot be empty or whitespace.")

    if not request.model_name or not request.model_name.strip():
        raise ValueError("CRITICAL: model_name cannot be empty or whitespace.")

    if request.sample_rate <= 0:
        raise ValueError(f"CRITICAL: sample_rate must be positive, got {request.sample_rate}.")


def synthesize_speech(request: TTSRequest) -> Path:
    validate_tts_request(request)
    project_id = resolve_project_id(request.project_id)

    creds, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
    creds.refresh(Request())

    url = (
        f"https://aiplatform.googleapis.com/v1/projects/{project_id}/"
        f"locations/global/publishers/google/models/{request.model_name}:generateContent"
    )
    headers = {
        "Authorization": f"Bearer {creds.token}",
        "Content-Type": "application/json",
    }

    user_part: dict[str, object] = {"text": request.text}
    if request.style_prompt is not None and request.style_prompt.strip():
        user_part["speechMetadata"] = {"style": request.style_prompt.strip()}

    payload: dict[str, object] = {
        "contents": [{"role": "user", "parts": [user_part]}],
        "generationConfig": {
            "responseModalities": ["AUDIO"],
            "speechConfig": {
                "voiceConfig": {
                    "prebuiltVoiceConfig": {
                        "voiceName": request.voice_name
                    }
                }
            },
        },
    }

    resp = requests.post(url, headers=headers, json=payload, timeout=120)
    if resp.status_code != 200:
        raise RuntimeError(
            f"CRITICAL: Gemini 3.8 Flash TTS API error ({resp.status_code}): {resp.text}"
        )

    data = resp.json()
    try:
        raw_b64 = data["candidates"][0]["content"]["parts"][0]["inlineData"]["data"]
    except (KeyError, IndexError, TypeError) as err:
        raise RuntimeError(f"CRITICAL: Unexpected payload from Gemini 3.8 TTS: {data}") from err

    wav_bytes = base64.b64decode(raw_b64)
    if not wav_bytes:
        raise RuntimeError("CRITICAL: Received empty audio payload from Gemini 3.8 TTS.")

    request.output_path.parent.mkdir(parents=True, exist_ok=True)
    temp_wav = request.output_path.with_suffix(".tmp.wav")
    temp_wav.write_bytes(wav_bytes)

    ffmpeg_bin = shutil.which("ffmpeg") or "ffmpeg"
    ffmpeg_cmd = [
        ffmpeg_bin,
        "-y",
        "-i",
        str(temp_wav),
        "-ar",
        str(request.sample_rate),
        "-b:a",
        request.bitrate,
        str(request.output_path),
    ]

    try:
        res = subprocess.run(
            ffmpeg_cmd,
            capture_output=True,
            text=True,
            check=False,
        )
        if res.returncode != 0:
            raise RuntimeError(f"CRITICAL: FFmpeg conversion to MP3 failed: {res.stderr}")
    finally:
        if temp_wav.is_file():
            temp_wav.unlink()

    return request.output_path
