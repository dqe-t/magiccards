from dataclasses import dataclass
from pathlib import Path
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from scripts.tts_generator import TTSRequest, synthesize_speech

LETTERS: list[str] = [chr(c) for c in range(ord("A"), ord("Z") + 1)]
NUMBERS: list[str] = [str(n) for n in range(1, 21)]

# Standard English phonics sound mapping (X excluded by design as per early phonics curriculum)
EN_PHONETIC_SOUND_MAP: dict[str, str] = {
    "A": "a",
    "B": "b",
    "C": "k",
    "D": "d",
    "E": "e",
    "F": "f",
    "G": "g",
    "H": "h",
    "I": "i",
    "J": "j",
    "K": "k",
    "L": "l",
    "M": "m",
    "N": "n",
    "O": "o",
    "P": "p",
    "Q": "qu",
    "R": "r",
    "S": "s",
    "T": "t",
    "U": "u",
    "V": "v",
    "W": "w",
    "Y": "y",
    "Z": "z",
}


@dataclass(frozen=True)
class AudioItemEN:
    filename: str
    text: str
    category: str  # "letter", "number", or "phonetic"
    utterance_type: str  # "question", "ans_pos", "ans_neg"
    symbol: str


def build_english_audio_manifest(include_phonetics: bool = True) -> list[AudioItemEN]:
    manifest: list[AudioItemEN] = []

    for letter in LETTERS:
        manifest.append(
            AudioItemEN(
                filename=f"q_letter_{letter}.mp3",
                text=f"Where is the letter {letter} ?",
                category="letter",
                utterance_type="question",
                symbol=letter,
            )
        )
        manifest.append(
            AudioItemEN(
                filename=f"ans_pos_letter_{letter}.mp3",
                text=f"Yes, that's the letter {letter} !",
                category="letter",
                utterance_type="ans_pos",
                symbol=letter,
            )
        )
        manifest.append(
            AudioItemEN(
                filename=f"ans_neg_letter_{letter}.mp3",
                text=f"No, that's the letter {letter}.",
                category="letter",
                utterance_type="ans_neg",
                symbol=letter,
            )
        )

    for num in NUMBERS:
        manifest.append(
            AudioItemEN(
                filename=f"q_number_{num}.mp3",
                text=f"Where is the number {num} ?",
                category="number",
                utterance_type="question",
                symbol=num,
            )
        )
        manifest.append(
            AudioItemEN(
                filename=f"ans_pos_number_{num}.mp3",
                text=f"Yes, that's the number {num} !",
                category="number",
                utterance_type="ans_pos",
                symbol=num,
            )
        )
        manifest.append(
            AudioItemEN(
                filename=f"ans_neg_number_{num}.mp3",
                text=f"No, that's the number {num}.",
                category="number",
                utterance_type="ans_neg",
                symbol=num,
            )
        )

    if include_phonetics:
        for letter, sound in EN_PHONETIC_SOUND_MAP.items():
            manifest.append(
                AudioItemEN(
                    filename=f"q_phonetic_{letter}.mp3",
                    text=f"Which letter makes the sound « {sound} » ?",
                    category="phonetic",
                    utterance_type="question",
                    symbol=letter,
                )
            )
            manifest.append(
                AudioItemEN(
                    filename=f"ans_pos_phonetic_{letter}.mp3",
                    text=f"Yes, that's the letter that makes the sound « {sound} » !",
                    category="phonetic",
                    utterance_type="ans_pos",
                    symbol=letter,
                )
            )
            manifest.append(
                AudioItemEN(
                    filename=f"ans_neg_phonetic_{letter}.mp3",
                    text=f"No, that's the letter that makes the sound « {sound} ».",
                    category="phonetic",
                    utterance_type="ans_neg",
                    symbol=letter,
                )
            )

    return manifest


def get_english_style_prompt(gender: str, item: AudioItemEN) -> str:
    if gender not in ("FEMALE", "MALE"):
        raise ValueError(f"CRITICAL: Unknown gender '{gender}'. Must be 'FEMALE' or 'MALE'.")

    role = "preschool teacher"
    gender_desc = "female" if gender == "FEMALE" else "male"

    if item.utterance_type == "question":
        return (
            f"Voice in English. {gender_desc.capitalize()} {role} voice, very warm, gentle, "
            f"inviting and clear diction for a young child. Natural and expressive English pronunciation."
        )
    if item.utterance_type == "ans_pos":
        return (
            f"Voice in English. {gender_desc.capitalize()} voice, joyful, encouraging, "
            f"celebratory and warm praise for a young child."
        )
    if item.utterance_type == "ans_neg":
        return (
            f"Voice in English. {gender_desc.capitalize()} voice, very gentle, warm, "
            f"slightly sympathetic but comforting and encouraging for a young child."
        )
    raise ValueError(f"CRITICAL: Unknown utterance type '{item.utterance_type}'.")


def generate_all_english_audio(project_root: Path | None = None) -> None:
    root = project_root or Path(__file__).resolve().parent.parent
    voices: list[tuple[str, str, str]] = [
        ("Kore", "FEMALE", "voice_female"),
        ("Fenrir", "MALE", "voice_male"),
    ]

    manifest = build_english_audio_manifest()
    total_files = len(voices) * len(manifest)
    print(f"Generating English audio batch ({total_files} total files)...")

    count = 0
    for voice_name, gender, subfolder in voices:
        target_dir = root / "assets" / "audio" / "en" / subfolder
        target_dir.mkdir(parents=True, exist_ok=True)

        for item in manifest:
            count += 1
            out_file = target_dir / item.filename

            if out_file.is_file() and out_file.stat().st_size > 1000:
                print(f"[{count}/{total_files}] Skipping existing: en/{subfolder}/{item.filename}")
                continue

            style = get_english_style_prompt(gender, item)
            req = TTSRequest(
                text=item.text,
                output_path=out_file,
                voice_name=voice_name,
                style_prompt=style,
            )

            retries = 3
            success = False
            while retries > 0 and not success:
                try:
                    synthesize_speech(req)
                    success = True
                    print(f"[{count}/{total_files}] Generated: en/{subfolder}/{item.filename}")
                except Exception as err:
                    retries -= 1
                    print(f"Error on {item.filename}: {err}. Retries left: {retries}")
                    if retries > 0:
                        time.sleep(2.0)
                    else:
                        raise

            time.sleep(0.12)


if __name__ == "__main__":
    generate_all_english_audio()
    print("English audio batch generation completed!")
