from pathlib import Path
import sys
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from scripts.generate_voice_samples_en import (
    get_english_style_prompt,
)


def test_get_english_style_prompt_happy_path() -> None:
    prompt_q_f = get_english_style_prompt("FEMALE", "question")
    assert "Female" in prompt_q_f
    assert "English" in prompt_q_f

    prompt_pos_m = get_english_style_prompt("MALE", "ans_pos")
    assert "Male" in prompt_pos_m
    assert "celebratory" in prompt_pos_m


def test_get_english_style_prompt_invalid_gender_failure() -> None:
    with pytest.raises(ValueError, match="CRITICAL: Unknown gender"):
        get_english_style_prompt("OTHER", "question")


def test_get_english_style_prompt_invalid_utterance_type_failure() -> None:
    with pytest.raises(ValueError, match="CRITICAL: Unknown utterance type"):
        get_english_style_prompt("FEMALE", "unsupported_type")
