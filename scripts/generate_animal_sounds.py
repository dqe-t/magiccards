import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from scripts.tts_generator import TTSRequest, synthesize_speech

ANIMAL_SOUND_MANIFEST: list[dict[str, str | int]] = [
    {
        "score": 0,
        "filename": "score_0_ant.mp3",
        "text": "Tchiki tchiki tchiki !",
        "style": (
            "Expressive, friendly children's storybook imitation of a tiny cute ant "
            "walking and scurrying fast with little cheerful sounds."
        ),
    },
    {
        "score": 1,
        "filename": "score_1_fly.mp3",
        "text": "Bzzzzzz ! Bzzzzzz !",
        "style": (
            "Playful, friendly children's storybook imitation of a cute little fly buzzing around happily."
        ),
    },
    {
        "score": 2,
        "filename": "score_2_frog.mp3",
        "text": "Coâââ, coâââ ! Coâââ !",
        "style": (
            "Friendly, funny, bouncy children's storybook imitation of a cute frog croaking happily in a pond."
        ),
    },
    {
        "score": 3,
        "filename": "score_3_duck.mp3",
        "text": "Coin, coin ! Coin, coin !",
        "style": (
            "Joyful, cheerful children's storybook imitation of a friendly little duck quacking happily."
        ),
    },
    {
        "score": 4,
        "filename": "score_4_bunny.mp3",
        "text": "Snif snif snif ! Hop, hop, hop !",
        "style": (
            "Cute, sweet, playful children's storybook imitation of a fluffy little bunny hopping and twitching its nose."
        ),
    },
    {
        "score": 5,
        "filename": "score_5_cat.mp3",
        "text": "Miaouuuu ! Ronronron...",
        "style": (
            "Gentle, adorable, affectionate children's storybook imitation of a cute kitten meowing and purring happily."
        ),
    },
    {
        "score": 6,
        "filename": "score_6_dog.mp3",
        "text": "Ouaf, ouaf ! Wouf, wouf !",
        "style": (
            "Playful, happy, energetic children's storybook imitation of a friendly puppy barking cheerfully."
        ),
    },
    {
        "score": 7,
        "filename": "score_7_fox.mp3",
        "text": "Yip, yip, yip ! Yap, yap !",
        "style": (
            "Clever, cheerful, playful children's storybook imitation of a cute little fox yipping and barking in the woods."
        ),
    },
    {
        "score": 8,
        "filename": "score_8_sheep.mp3",
        "text": "Bêêêêê ! Bêêê !",
        "style": (
            "Warm, funny, gentle children's storybook imitation of a fluffy sheep bleating happily."
        ),
    },
    {
        "score": 9,
        "filename": "score_9_lion.mp3",
        "text": "Rroaaarrr ! Grrr... Rroaarr !",
        "style": (
            "Cute, energetic children's storybook imitation of a brave little baby lion cub practicing a friendly roar."
        ),
    },
    {
        "score": 10,
        "filename": "score_10_bear.mp3",
        "text": "Grrrr... ROAAARRRRR !",
        "style": (
            "Expressive children's storybook narrator imitating a big friendly bear making a rumbling roar and growl."
        ),
    },
]


def main() -> None:
    out_dir = Path("assets/audio/animals")
    out_dir.mkdir(parents=True, exist_ok=True)

    # Note: Bear sound was already tested and synthesized in output/bear_roar_puck.mp3!
    bear_cache = Path("output/bear_roar_puck.mp3")

    print(f"Generating 11 animal sounds with voice 'Puck' (Gemini 3.8 Flash TTS)...")

    for item in ANIMAL_SOUND_MANIFEST:
        score = int(item["score"])
        filename = str(item["filename"])
        text = str(item["text"])
        style = str(item["style"])
        out_file = out_dir / filename

        print(f"\n--- Score {score}: {filename} ---")
        if score == 10 and bear_cache.is_file():
            import shutil
            shutil.copy2(bear_cache, out_file)
            print(f"Reused existing bear roar from {bear_cache} -> {out_file}")
            continue

        retries = 3
        while retries > 0:
            try:
                req = TTSRequest(
                    text=text,
                    output_path=out_file,
                    voice_name="Puck",
                    style_prompt=style,
                    model_name="gemini-3.8-flash-tts",
                )
                res = synthesize_speech(req)
                print(f"Success! Saved to {res} ({res.stat().st_size} bytes)")
                break
            except Exception as e:
                retries -= 1
                print(f"Error synthesizing {filename}: {e}. Retries left: {retries}")
                time.sleep(2)
                if retries == 0:
                    raise

    print("\nAll 11 animal sounds successfully generated and placed in assets/audio/animals/!")


if __name__ == "__main__":
    main()
