import os
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from scripts.tts_generator import TTSRequest, synthesize_speech

CANDIDATE_VOICES: dict[str, str] = {
    "Aoede": "FEMALE",
    "Kore": "FEMALE",
    "Puck": "MALE",
    "Fenrir": "MALE",
    "Enceladus": "MALE",
}

def get_style_prompt(gender: str, utterance_type: str) -> str:
    if utterance_type == "q_letter":
        role = "d'institutrice" if gender == "FEMALE" else "d'instituteur"
        gender_desc = "féminine" if gender == "FEMALE" else "masculine"
        return (
            f"Voix en français. Voix {gender_desc} {role}, ton très chaleureux, doux, "
            f"bienveillant et invitant pour un jeune enfant. Prononciation claire et distincte de la langue française."
        )
    if utterance_type == "q_number":
        role = "d'institutrice" if gender == "FEMALE" else "d'instituteur"
        gender_desc = "féminine" if gender == "FEMALE" else "masculine"
        return (
            f"Voix en français. Voix {gender_desc} {role}, ton curieux, enthousiaste "
            f"et très doux pour un enfant. Prononciation claire et distincte de la langue française."
        )
    if utterance_type == "ans_pos":
        gender_desc = "féminine" if gender == "FEMALE" else "masculine"
        return (
            f"Voix en français. Voix {gender_desc}, extrêmement joyeuse, fière, "
            f"enthousiaste et festive, félicitant chaleureusement un enfant."
        )
    if utterance_type == "ans_neg":
        gender_desc = "féminine" if gender == "FEMALE" else "masculine"
        return (
            f"Voix en français. Voix {gender_desc}, très douce, bienveillante, "
            f"légèrement triste mais très encourageante et réconfortante pour un enfant."
        )
    raise ValueError(f"CRITICAL: Unknown utterance type '{utterance_type}'.")


SAMPLE_ITEMS: list[dict[str, str]] = [
    {"type": "q_letter", "filename": "q_letter_A.mp3", "text": "Où est la lettre A ?"},
    {"type": "q_number", "filename": "q_number_1.mp3", "text": "Où est le chiffre 1 ?"},
    {"type": "ans_pos", "filename": "ans_pos_letter_A.mp3", "text": "Oui, c'est la lettre A !"},
    {"type": "ans_neg", "filename": "ans_neg_letter_B.mp3", "text": "Non, c'est la lettre B."},
]


def generate_samples(output_dir: Path | None = None) -> list[Path]:
    target_dir = output_dir or (Path(__file__).resolve().parent.parent / "output" / "voice_samples")
    target_dir.mkdir(parents=True, exist_ok=True)

    generated: list[Path] = []
    for voice_name, gender in CANDIDATE_VOICES.items():
        voice_folder = target_dir / f"{gender.lower()}_{voice_name.lower()}"
        voice_folder.mkdir(parents=True, exist_ok=True)
        print(f"Generating samples for {voice_name} ({gender})...")

        for item in SAMPLE_ITEMS:
            file_path = voice_folder / item["filename"]
            style = get_style_prompt(gender, item["type"])
            request = TTSRequest(
                text=item["text"],
                output_path=file_path,
                voice_name=voice_name,
                style_prompt=style,
            )
            saved = synthesize_speech(request)
            print(f"  -> Generated: {saved.name} ({saved.stat().st_size} bytes)")
            generated.append(saved)

    return generated


if __name__ == "__main__":
    out_files = generate_samples()
    print(f"\nAll done! Generated {len(out_files)} sample files.")
