from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from scripts.tts_generator import TTSRequest, synthesize_speech

def test_bear_roar() -> None:
    output_dir = Path("output")
    output_dir.mkdir(parents=True, exist_ok=True)

    experiments = [
        {
            "name": "bear_roar_fenrir",
            "voice": "Fenrir",
            "text": "Roaaarrrrrr !",
            "style": (
                "Deep, guttural, low-pitched bear roar. The speaker is energetically imitating a massive wild bear "
                "roaring in the deep woods with a ferocious, rumbling growl and loud roar."
            ),
        },
        {
            "name": "bear_roar_puck",
            "voice": "Puck",
            "text": "Grrrr... ROAAARRRRR !",
            "style": (
                "Fun and expressive children's storybook narrator imitating a big friendly but ferocious bear "
                "making a deep, rumbling bear roar and growl."
            ),
        },
        {
            "name": "bear_roar_charon",
            "voice": "Charon",
            "text": "ROOOAAARRRRRR !",
            "style": (
                "Deep, booming, guttural animal roar. A powerful imitation of a huge grizzly bear roaring loudly."
            ),
        },
    ]

    for exp in experiments:
        out_file = output_dir / f"{exp['name']}.mp3"
        print(f"\n--- Synthesizing {exp['name']} ({exp['voice']}) ---")
        try:
            req = TTSRequest(
                text=exp["text"],
                output_path=out_file,
                voice_name=exp["voice"],
                style_prompt=exp["style"],
                model_name="gemini-3.8-flash-tts",
            )
            res = synthesize_speech(req)
            print(f"Success! Saved to {res} (size: {res.stat().st_size} bytes)")
        except Exception as e:
            print(f"Error synthesizing {exp['name']}: {type(e).__name__}: {e}")

if __name__ == "__main__":
    test_bear_roar()
