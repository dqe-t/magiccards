from pathlib import Path
import sys
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from scripts.generate_all_audio_en import (
    AudioItemEN,
    EN_PHONETIC_SOUND_MAP,
    build_english_audio_manifest,
    get_english_style_prompt,
)


def test_build_english_audio_manifest_structure() -> None:
    manifest = build_english_audio_manifest(include_phonetics=True)
    # 26 letters * 3 = 78, 20 numbers * 3 = 60, 25 phonetics (excluding X) * 3 = 75 => total 213
    letters = [item for item in manifest if item.category == "letter"]
    numbers = [item for item in manifest if item.category == "number"]
    phonetics = [item for item in manifest if item.category == "phonetic"]

    assert len(letters) == 78
    assert len(numbers) == 60
    assert len(phonetics) == len(EN_PHONETIC_SOUND_MAP) * 3
    assert "X" not in EN_PHONETIC_SOUND_MAP
    assert "H" in EN_PHONETIC_SOUND_MAP  # Unlike French, English H has a sound
    assert "W" in EN_PHONETIC_SOUND_MAP


def test_get_english_style_prompt_happy_paths() -> None:
    item_q = AudioItemEN(
        filename="q_letter_A.mp3",
        text="Where is the letter A ?",
        category="letter",
        utterance_type="question",
        symbol="A",
    )
    prompt_f = get_english_style_prompt("FEMALE", item_q)
    prompt_m = get_english_style_prompt("MALE", item_q)

    assert "English" in prompt_f and "Female" in prompt_f
    assert "English" in prompt_m and "Male" in prompt_m


def test_get_english_style_prompt_invalid_gender_failure() -> None:
    item = AudioItemEN("test.mp3", "test", "letter", "question", "A")
    with pytest.raises(ValueError, match="CRITICAL: Unknown gender"):
        get_english_style_prompt("INVALID", item)


def test_get_english_style_prompt_invalid_utterance_type_failure() -> None:
    item = AudioItemEN("test.mp3", "test", "letter", "bad_type", "A")
    with pytest.raises(ValueError, match="CRITICAL: Unknown utterance type"):
        get_english_style_prompt("FEMALE", item)
