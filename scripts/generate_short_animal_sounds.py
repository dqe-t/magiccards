from argparse import ArgumentParser
from pathlib import Path
import shutil
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from scripts.tts_generator import (
    TTSRequest,
    build_french_style_prompt,
    synthesize_speech,
    validate_french_style_prompt,
)

ANIMAL_AUDIO_MANIFEST_FR: list[dict[str, object]] = [
    {
        "score": 0,
        "name": "ant",
        "voice": "Aoede",
        "text": "Hop, hop ! Courage, réessaie !",
        "style": build_french_style_prompt(
            "Voix d'institutrice très bienveillante et énergique imitant de petits pas vifs d'une fourmi, "
            "suivis d'un encouragement chaleureux : Hop, hop ! Courage, réessaie !"
        ),
    },
    {
        "score": 1,
        "name": "fly",
        "voice": "Aoede",
        "text": "Bzz, bzz ! Continue, tu peux le faire !",
        "style": build_french_style_prompt(
            "Voix joyeuse d'institutrice imitant le vol joueur d'une mouche, "
            "suivi d'un encouragement très enthousiaste : Bzz, bzz ! Continue, tu peux le faire !"
        ),
    },
    {
        "score": 2,
        "name": "frog",
        "voice": "Puck",
        "text": "Coâ, coâ ! C'est un bon début !",
        "style": build_french_style_prompt(
            "Voix amicale d'instituteur imitant le coassement d'une grenouille rigolote, "
            "suivi d'un encouragement chaleureux : Coâ, coâ ! C'est un bon début !"
        ),
    },
    {
        "score": 3,
        "name": "duck",
        "voice": "Aoede",
        "text": "Coin, coin ! Tu apprends vite !",
        "style": build_french_style_prompt(
            "Voix joyeuse d'institutrice imitant le cancanement joueur d'un petit canard, "
            "suivi d'un encouragement très positif : Coin, coin ! Tu apprends vite !"
        ),
    },
    {
        "score": 4,
        "name": "bunny",
        "voice": "Aoede",
        "text": "Hop, hop ! Continue comme ça !",
        "style": build_french_style_prompt(
            "Voix douce et dynamique d'institutrice imitant les petits sauts d'un lapin mignon, "
            "suivis d'un encouragement motivant : Hop, hop ! Continue comme ça !"
        ),
    },
    {
        "score": 5,
        "name": "cat",
        "voice": "Aoede",
        "text": "Miaou, miaou ! C'est super !",
        "style": build_french_style_prompt(
            "Voix tendre et joyeuse d'institutrice imitant le miaulement affectueux d'un chaton, "
            "suivi d'une vive félicitation : Miaou, miaou ! C'est super !"
        ),
    },
    {
        "score": 6,
        "name": "dog",
        "voice": "Puck",
        "text": "Ouaf, ouaf ! Tu y es presque !",
        "style": build_french_style_prompt(
            "Voix chaleureuse d'instituteur imitant l'aboiement joueur d'un chiot enthousiaste, "
            "suivi d'un encouragement énergique : Ouaf, ouaf ! Tu y es presque !"
        ),
    },
    {
        "score": 7,
        "name": "fox",
        "voice": "Puck",
        "text": "Yap, yap ! Bien joué, petit malin !",
        "style": build_french_style_prompt(
            "Voix malicieuse et complice d'instituteur imitant un petit renard rusé, "
            "suivie d'une félicitation joyeuse : Yap, yap ! Bien joué, petit malin !"
        ),
    },
    {
        "score": 8,
        "name": "sheep",
        "voice": "Aoede",
        "text": "Bêê, bêê ! Formidable !",
        "style": build_french_style_prompt(
            "Voix douce et festive d'institutrice imitant le bêlement d'un gentil mouton, "
            "suivi d'une grande exclamation festive et admirative : Bêê, bêê ! Formidable !"
        ),
    },
    {
        "score": 9,
        "name": "lion",
        "voice": "Puck",
        "text": "Wrrroaaarrr ! Très bien !",
        "style": build_french_style_prompt(
            "Voix puissante et festive d'instituteur imitant le rugissement fier d'un lionceau brave, "
            "suivi d'une félicitation joyeuse et chaleureuse : Wrrroaaarrr ! Très bien !"
        ),
    },
    {
        "score": 10,
        "name": "bear",
        "voice": "Puck",
        "text": "Grroaar ! Parfait !",
        "style": build_french_style_prompt(
            "Voix masculine d'instituteur imitant le grand rugissement chaleureux d'un ours bienveillant, "
            "suivi d'une félicitation festive et triomphale pour un score parfait : Grroaar ! Parfait ! "
            "Prononciation française soignée du mot « Parfait » avec le son 'è' /paʁfɛ/ et r français, jamais à l'américaine."
        ),
    },
]

ANIMAL_AUDIO_MANIFEST_EN: list[dict[str, object]] = [
    {
        "score": 0,
        "name": "ant",
        "voice": "Kore",
        "text": "Hop, hop ! Don't give up, try again !",
        "style": (
            "Voice in English. Warm, energetic female preschool teacher voice imitating tiny brisk ant footsteps "
            "then encouraging cheer: Hop, hop ! Don't give up, try again !"
        ),
    },
    {
        "score": 1,
        "name": "fly",
        "voice": "Kore",
        "text": "Bzz, bzz ! Keep going, you can do it !",
        "style": (
            "Voice in English. Cheerful female preschool teacher voice imitating playful buzzy fly "
            "then encouraging cheer: Bzz, bzz ! Keep going, you can do it !"
        ),
    },
    {
        "score": 2,
        "name": "frog",
        "voice": "Fenrir",
        "text": "Ribbit, ribbit ! That's a good start !",
        "style": (
            "Voice in English. Friendly male preschool teacher voice imitating cute frog croak "
            "then positive encouragement: Ribbit, ribbit ! That's a good start !"
        ),
    },
    {
        "score": 3,
        "name": "duck",
        "voice": "Kore",
        "text": "Quack, quack ! You're learning fast !",
        "style": (
            "Voice in English. Cheerful female preschool teacher voice imitating playful duck quack "
            "then positive encouragement: Quack, quack ! You're learning fast !"
        ),
    },
    {
        "score": 4,
        "name": "bunny",
        "voice": "Kore",
        "text": "Hop, hop ! Keep it up, you're doing great !",
        "style": (
            "Voice in English. Cheerful female preschool teacher voice imitating cute bunny hops "
            "then energetic encouragement: Hop, hop ! Keep it up, you're doing great !"
        ),
    },
    {
        "score": 5,
        "name": "cat",
        "voice": "Kore",
        "text": "Meow, meow ! That's wonderful !",
        "style": (
            "Voice in English. Warm female preschool teacher voice imitating sweet kitten meow "
            "then enthusiastic cheer: Meow, meow ! That's wonderful !"
        ),
    },
    {
        "score": 6,
        "name": "dog",
        "voice": "Fenrir",
        "text": "Woof, woof ! You're getting there !",
        "style": (
            "Voice in English. Cheerful male preschool teacher voice imitating energetic puppy bark "
            "then encouraging cheer: Woof, woof ! You're getting there !"
        ),
    },
    {
        "score": 7,
        "name": "fox",
        "voice": "Fenrir",
        "text": "Yap, yap ! Well played, clever one !",
        "style": (
            "Voice in English. Playful male preschool teacher voice imitating clever little fox yip "
            "then cheerful praise: Yap, yap ! Well played, clever one !"
        ),
    },
    {
        "score": 8,
        "name": "sheep",
        "voice": "Kore",
        "text": "Baa, baa ! Fantastic work !",
        "style": (
            "Voice in English. Warm female preschool teacher voice imitating friendly gentle sheep bleat "
            "then celebratory praise: Baa, baa ! Fantastic work !"
        ),
    },
    {
        "score": 9,
        "name": "lion",
        "voice": "Fenrir",
        "text": "Roarrr ! Very good !",
        "style": (
            "Voice in English. Child-friendly male voice imitating friendly baby lion cub roar "
            "then celebratory praise: Roarrr ! Very good !"
        ),
    },
    {
        "score": 10,
        "name": "bear",
        "voice": "Fenrir",
        "text": "Grroaar ! Perfect !",
        "style": (
            "Voice in English. Warm, celebratory male preschool teacher voice imitating friendly bear growl "
            "and roar then triumphant praise: Grroaar ! Perfect !"
        ),
    },
]


def get_duration(mp3_path: Path) -> float:
    if not mp3_path.is_file():
        raise FileNotFoundError(f"CRITICAL: Audio file not found at {mp3_path}.")
    ffprobe_bin = shutil.which("ffprobe") or "ffprobe"
    cmd = [
        ffprobe_bin,
        "-v",
        "error",
        "-show_entries",
        "format=duration",
        "-of",
        "default=noprint_wrappers=1:nokey=1",
        str(mp3_path),
    ]
    res = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return float(res.stdout.strip())


def generate_mascot_audio_item(item: dict[str, object], dest_dir: Path, is_french: bool) -> Path:
    score = int(item["score"])  # type: ignore[arg-type]
    name = str(item["name"])
    voice_name = str(item["voice"])
    text = str(item["text"])
    style = str(item["style"])

    if is_french:
        validate_french_style_prompt(style)

    filename = f"score_{score}_{name}.mp3"
    out_file = dest_dir / filename

    print(f"Generating score {score}: {name} ({voice_name})...")
    req = TTSRequest(
        text=text,
        output_path=out_file,
        voice_name=voice_name,
        style_prompt=style,
    )

    retries = 3
    while retries > 0:
        try:
            synthesize_speech(req)
            dur = get_duration(out_file)
            print(f"  -> Saved {out_file.name}: duration = {dur:.2f}s (voice: {voice_name})")
            return out_file
        except Exception as e:
            retries -= 1
            print(f"  -> Error: {e}, retries left: {retries}")
            if retries == 0:
                raise
            time.sleep(2)

    raise RuntimeError(f"CRITICAL: Failed to generate audio for score {score}")


def sync_existing_french_to_subfolder(animals_dir: Path) -> None:
    fr_dir = animals_dir / "fr"
    fr_dir.mkdir(parents=True, exist_ok=True)
    for mp3_file in animals_dir.glob("score_*.mp3"):
        dst = fr_dir / mp3_file.name
        if not dst.is_file() or dst.stat().st_size != mp3_file.stat().st_size:
            shutil.copy2(mp3_file, dst)
            print(f"Synced {mp3_file.name} to {dst}")


def main() -> None:
    parser = ArgumentParser(description="Generate mascot animal reward audio files (French and English).")
    parser.add_argument("--score", type=int, default=None, help="Specific score (0-10) to regenerate.")
    parser.add_argument("--lang", type=str, default="all", choices=["fr", "en", "all"], help="Language to generate.")
    args = parser.parse_args()

    animals_dir = Path(__file__).resolve().parent.parent / "assets" / "audio" / "animals"
    animals_dir.mkdir(parents=True, exist_ok=True)
    sync_existing_french_to_subfolder(animals_dir)

    if args.lang in ("fr", "all"):
        fr_dir = animals_dir / "fr"
        fr_items = (
            [it for it in ANIMAL_AUDIO_MANIFEST_FR if it["score"] == args.score]
            if args.score is not None
            else ANIMAL_AUDIO_MANIFEST_FR
        )
        print(f"\n--- Generating French Mascot Sounds ({len(fr_items)} items) ---")
        for item in fr_items:
            out = generate_mascot_audio_item(item, fr_dir, is_french=True)
            # Also keep root copy for fallback
            shutil.copy2(out, animals_dir / out.name)

    if args.lang in ("en", "all"):
        en_dir = animals_dir / "en"
        en_dir.mkdir(parents=True, exist_ok=True)
        en_items = (
            [it for it in ANIMAL_AUDIO_MANIFEST_EN if it["score"] == args.score]
            if args.score is not None
            else ANIMAL_AUDIO_MANIFEST_EN
        )
        print(f"\n--- Generating English Mascot Sounds ({len(en_items)} items) ---")
        for item in en_items:
            generate_mascot_audio_item(item, en_dir, is_french=False)

    print("\nMascot generation completed!")


if __name__ == "__main__":
    main()
