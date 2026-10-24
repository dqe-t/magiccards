import argparse
from dataclasses import dataclass
from pathlib import Path
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from scripts.tts_generator import TTSRequest, synthesize_speech

ALL_PHONETIC_LETTERS: list[str] = [
    "A", "B", "C", "D", "E", "F", "G", "I", "J", "K", "L", "M",
    "N", "O", "P", "Q", "R", "S", "T", "U", "V", "Y", "Z",
]

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
class PhoneticAudioItem:
    filename: str
    text: str
    symbol: str
    utterance_type: str  # "question", "ans_pos", "ans_neg"


def build_phonetic_manifest(symbols: list[str] | None = None) -> list[PhoneticAudioItem]:
    target_symbols = symbols or ALL_PHONETIC_LETTERS
    manifest: list[PhoneticAudioItem] = []

    for sym in target_symbols:
        upper_sym = sym.upper()
        sound = PHONETIC_SOUND_MAP.get(upper_sym)
        if sound is None:
            raise ValueError(f"CRITICAL: No phonetic sound mapping defined for '{upper_sym}'.")

        manifest.append(
            PhoneticAudioItem(
                filename=f"q_phonetic_{upper_sym}.mp3",
                text=f"Quelle lettre fait le son « {sound} » ?",
                symbol=upper_sym,
                utterance_type="question",
            )
        )
        manifest.append(
            PhoneticAudioItem(
                filename=f"ans_pos_phonetic_{upper_sym}.mp3",
                text=f"Oui, c'est la lettre qui fait le son « {sound} » !",
                symbol=upper_sym,
                utterance_type="ans_pos",
            )
        )
        manifest.append(
            PhoneticAudioItem(
                filename=f"ans_neg_phonetic_{upper_sym}.mp3",
                text=f"Non, c'est la lettre qui fait le son « {sound} ».",
                symbol=upper_sym,
                utterance_type="ans_neg",
            )
        )

    return manifest


def get_phonetic_style_prompt(gender: str, item: PhoneticAudioItem) -> str:
    if gender not in ("FEMALE", "MALE"):
        raise ValueError(f"CRITICAL: gender must be 'FEMALE' or 'MALE', got '{gender}'.")

    role = "d'institutrice" if gender == "FEMALE" else "d'instituteur"
    gender_desc = "féminine" if gender == "FEMALE" else "masculine"

    if item.utterance_type == "question":
        return (
            f"Voix en français. Voix {gender_desc} {role}, ton très chaleureux, doux, "
            f"bienveillant pour un jeune enfant. Énoncer distinctement et clairement la question et le son demandé."
        )
    if item.utterance_type == "ans_pos":
        return (
            f"Voix en français. Voix {gender_desc}, joyeuse, enthousiaste, félicitant un enfant avec fierté."
        )
    return (
        f"Voix en français. Voix {gender_desc}, douce, bienveillante et encourageante pour un enfant."
    )


def generate_phonetic_samples(
    assets_dir: Path,
    symbols: list[str] | None = None,
    dry_run: bool = False,
    force: bool = False,
    delay_seconds: float = 0.5,
) -> list[Path]:
    manifest = build_phonetic_manifest(symbols)
    voice_configs: list[tuple[str, str, str]] = [
        ("FEMALE", "voice_female", "Aoede"),
        ("MALE", "voice_male", "Puck"),
    ]

    generated_files: list[Path] = []

    for gender, folder_name, voice_name in voice_configs:
        target_dir = assets_dir / "audio" / folder_name
        target_dir.mkdir(parents=True, exist_ok=True)

        for item in manifest:
            out_path = target_dir / item.filename
            if not force and out_path.is_file() and out_path.stat().st_size > 1000:
                generated_files.append(out_path)
                continue

            if dry_run:
                generated_files.append(out_path)
                continue

            style = get_phonetic_style_prompt(gender, item)
            req = TTSRequest(
                text=item.text,
                output_path=out_path,
                voice_name=voice_name,
                style_prompt=style,
            )
            synthesize_speech(req)
            generated_files.append(out_path)
            time.sleep(delay_seconds)

    return generated_files


def parse_cli_args(args: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate sample phonetic audio files.")
    parser.add_argument("--dry-run", action="store_true", help="Validate without making API calls.")
    parser.add_argument("--force", action="store_true", help="Re-generate even if file exists.")
    parser.add_argument("--symbols", nargs="+", default=None, help="Specific symbols to generate.")
    return parser.parse_args(args)


def main() -> int:
    args = parse_cli_args()
    base_assets = Path(__file__).resolve().parent.parent / "assets"
    res = generate_phonetic_samples(
        assets_dir=base_assets,
        symbols=args.symbols,
        dry_run=args.dry_run,
        force=args.force,
    )
    print(f"Generated/verified {len(res)} phonetic sample clips.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
