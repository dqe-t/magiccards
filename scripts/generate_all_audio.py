from dataclasses import dataclass
from pathlib import Path
import shutil
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from scripts.tts_generator import TTSRequest, synthesize_speech

LETTERS: list[str] = [chr(c) for c in range(ord("A"), ord("Z") + 1)]
NUMBERS: list[str] = [str(n) for n in range(1, 21)]
PHONETIC_SOUND_MAP: dict[str, str] = {
    "A": "a",
    "B": "b",
    "C": "k",
    "D": "d",
    "E": "e",
    "F": "f",
    "G": "g",
    "I": "i",
    "J": "j",
    "K": "k",
    "L": "l",
    "M": "m",
    "N": "n",
    "O": "o",
    "P": "p",
    "Q": "k",
    "R": "r",
    "S": "s",
    "T": "t",
    "U": "u",
    "V": "v",
    "Y": "i",
    "Z": "z",
}


@dataclass(frozen=True)
class AudioItem:
    filename: str
    text: str
    category: str  # "letter", "number", or "phonetic"
    utterance_type: str  # "question", "ans_pos", "ans_neg"
    symbol: str


def build_audio_manifest(include_phonetics: bool = True) -> list[AudioItem]:
    manifest: list[AudioItem] = []

    for letter in LETTERS:
        manifest.append(
            AudioItem(
                filename=f"q_letter_{letter}.mp3",
                text=f"Où est la lettre {letter} ?",
                category="letter",
                utterance_type="question",
                symbol=letter,
            )
        )
        manifest.append(
            AudioItem(
                filename=f"ans_pos_letter_{letter}.mp3",
                text=f"Oui, c'est la lettre {letter} !",
                category="letter",
                utterance_type="ans_pos",
                symbol=letter,
            )
        )
        manifest.append(
            AudioItem(
                filename=f"ans_neg_letter_{letter}.mp3",
                text=f"Non, c'est la lettre {letter}.",
                category="letter",
                utterance_type="ans_neg",
                symbol=letter,
            )
        )

    for num in NUMBERS:
        manifest.append(
            AudioItem(
                filename=f"q_number_{num}.mp3",
                text=f"Où est le chiffre {num} ?",
                category="number",
                utterance_type="question",
                symbol=num,
            )
        )
        manifest.append(
            AudioItem(
                filename=f"ans_pos_number_{num}.mp3",
                text=f"Oui, c'est le chiffre {num} !",
                category="number",
                utterance_type="ans_pos",
                symbol=num,
            )
        )
        manifest.append(
            AudioItem(
                filename=f"ans_neg_number_{num}.mp3",
                text=f"Non, c'est le chiffre {num}.",
                category="number",
                utterance_type="ans_neg",
                symbol=num,
            )
        )

    if include_phonetics:
        for letter, sound in PHONETIC_SOUND_MAP.items():
            manifest.append(
                AudioItem(
                    filename=f"q_phonetic_{letter}.mp3",
                    text=f"Quelle lettre fait le son « {sound} » ?",
                    category="phonetic",
                    utterance_type="question",
                    symbol=letter,
                )
            )
            manifest.append(
                AudioItem(
                    filename=f"ans_pos_phonetic_{letter}.mp3",
                    text=f"Oui, c'est la lettre qui fait le son « {sound} » !",
                    category="phonetic",
                    utterance_type="ans_pos",
                    symbol=letter,
                )
            )
            manifest.append(
                AudioItem(
                    filename=f"ans_neg_phonetic_{letter}.mp3",
                    text=f"Non, c'est la lettre qui fait le son « {sound} ».",
                    category="phonetic",
                    utterance_type="ans_neg",
                    symbol=letter,
                )
            )

    return manifest


def get_style_prompt(gender: str, item: AudioItem) -> str:
    role = "d'institutrice" if gender == "FEMALE" else "d'instituteur"
    gender_desc = "féminine" if gender == "FEMALE" else "masculine"

    if item.utterance_type == "question":
        return (
            f"Voix en français. Voix {gender_desc} {role}, ton très chaleureux, doux, "
            f"bienveillant et invitant pour un jeune enfant. Prononciation claire et distincte de la langue française."
        )
    if item.utterance_type == "ans_pos":
        return (
            f"Voix en français. Voix {gender_desc}, extrêmement joyeuse, fière, "
            f"enthousiaste et festive, félicitant chaleureusement un enfant."
        )
    if item.utterance_type == "ans_neg":
        return (
            f"Voix en français. Voix {gender_desc}, très douce, bienveillante, "
            f"légèrement triste mais très encourageante et réconfortante pour un enfant."
        )
    raise ValueError(f"CRITICAL: Unknown utterance type '{item.utterance_type}'.")


def copy_sfx_assets(project_root: Path) -> None:
    src_dir = project_root / "sounds_downloaded"
    dst_dir = project_root / "assets" / "audio" / "sfx"
    dst_dir.mkdir(parents=True, exist_ok=True)

    correct_src = src_dir / "selection_correct.mp3"
    wrong_src = src_dir / "selection_wrong.wav"

    if correct_src.is_file():
        shutil.copy2(correct_src, dst_dir / "correct.mp3")
        print(f"Copied SFX: {dst_dir / 'correct.mp3'}")
    if wrong_src.is_file():
        shutil.copy2(wrong_src, dst_dir / "wrong.wav")
        print(f"Copied SFX: {dst_dir / 'wrong.wav'}")


def generate_all_audio(project_root: Path | None = None) -> None:
    root = project_root or Path(__file__).resolve().parent.parent
    copy_sfx_assets(root)

    voices: list[tuple[str, str, str]] = [
        ("Aoede", "FEMALE", "voice_female"),
        ("Puck", "MALE", "voice_male"),
    ]

    manifest = build_audio_manifest()
    total_files = len(voices) * len(manifest)
    print(f"Generating full audio batch ({total_files} total files)...")

    count = 0
    for voice_name, gender, subfolder in voices:
        target_dir = root / "assets" / "audio" / subfolder
        target_dir.mkdir(parents=True, exist_ok=True)

        for item in manifest:
            count += 1
            out_file = target_dir / item.filename

            if out_file.is_file() and out_file.stat().st_size > 1000:
                print(f"[{count}/{total_files}] Skipping existing: {subfolder}/{item.filename}")
                continue

            style = get_style_prompt(gender, item)
            request = TTSRequest(
                text=item.text,
                output_path=out_file,
                voice_name=voice_name,
                style_prompt=style,
            )

            retries = 3
            success = False
            while retries > 0 and not success:
                try:
                    synthesize_speech(request)
                    success = True
                    print(f"[{count}/{total_files}] Generated: {subfolder}/{item.filename}")
                except Exception as err:
                    retries -= 1
                    print(f"Error on {item.filename}: {err}. Retries left: {retries}")
                    if retries > 0:
                        time.sleep(2.0)
                    else:
                        raise

            time.sleep(0.15)


if __name__ == "__main__":
    generate_all_audio()
    print("Full audio generation completed!")
