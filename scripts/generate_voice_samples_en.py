from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from src.tts_generator import TTSRequest, synthesize_speech

EN_CANDIDATE_VOICES: dict[str, str] = {
    "Kore": "FEMALE",
    "Fenrir": "MALE",
}


def get_english_style_prompt(gender: str, utterance_type: str) -> str:
    if gender not in ("FEMALE", "MALE"):
        raise ValueError(f"CRITICAL: Unknown gender '{gender}'. Must be 'FEMALE' or 'MALE'.")

    role = "preschool teacher"
    gender_desc = "female" if gender == "FEMALE" else "male"

    if utterance_type == "question":
        return (
            f"Voice in English. {gender_desc.capitalize()} {role} voice, very warm, gentle, "
            f"inviting and clear diction for a young child. Natural and expressive English pronunciation."
        )
    if utterance_type == "ans_pos":
        return (
            f"Voice in English. {gender_desc.capitalize()} voice, joyful, encouraging, "
            f"celebratory and warm praise for a young child."
        )
    if utterance_type == "ans_neg":
        return (
            f"Voice in English. {gender_desc.capitalize()} voice, very gentle, warm, "
            f"slightly sympathetic but comforting and encouraging for a young child."
        )
    raise ValueError(f"CRITICAL: Unknown utterance type '{utterance_type}'.")


SAMPLE_ITEMS: list[dict[str, str]] = [
    {"type": "question", "filename": "q_number_3.mp3", "text": "Where is the number 3 ?"},
    {"type": "ans_pos", "filename": "ans_pos_number_3.mp3", "text": "Yes, that's the number 3 !"},
    {"type": "question", "filename": "q_letter_A.mp3", "text": "Where is the letter A ?"},
    {"type": "ans_pos", "filename": "ans_pos_letter_A.mp3", "text": "Yes, that's the letter A !"},
]


def generate_english_samples(output_dir: Path | None = None) -> list[Path]:
    target_dir = output_dir or (Path(__file__).resolve().parent.parent / "tmp" / "voice_samples_en")
    target_dir.mkdir(parents=True, exist_ok=True)

    generated: list[Path] = []
    for voice_name, gender in EN_CANDIDATE_VOICES.items():
        subfolder = target_dir / f"{gender.lower()}_{voice_name.lower()}"
        subfolder.mkdir(parents=True, exist_ok=True)

        items_for_voice = (
            [SAMPLE_ITEMS[0], SAMPLE_ITEMS[1]]
            if gender == "FEMALE"
            else [SAMPLE_ITEMS[2], SAMPLE_ITEMS[3]]
        )

        for item in items_for_voice:
            out_file = subfolder / item["filename"]
            style = get_english_style_prompt(gender, item["type"])
            req = TTSRequest(
                text=item["text"],
                output_path=out_file,
                voice_name=voice_name,
                style_prompt=style,
            )
            saved = synthesize_speech(req)
            generated.append(saved)
            print(f"Generated {voice_name}: {saved.name}")

    return generated


if __name__ == "__main__":
    generate_english_samples()
