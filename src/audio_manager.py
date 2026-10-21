from pathlib import Path
import random
import sys
from typing import Literal
import pygame

VoiceType = Literal["FEMALE", "MALE"]
LanguageType = Literal["FR", "EN"]


SCORE_ANIMAL_AUDIO_MAP: dict[int, str] = {
    0: "score_0_ant.mp3",
    1: "score_1_fly.mp3",
    2: "score_2_frog.mp3",
    3: "score_3_duck.mp3",
    4: "score_4_bunny.mp3",
    5: "score_5_cat.mp3",
    6: "score_6_dog.mp3",
    7: "score_7_fox.mp3",
    8: "score_8_sheep.mp3",
    9: "score_9_lion.mp3",
    10: "score_10_bear.mp3",
}


def get_default_assets_dir() -> Path:
    if getattr(sys, "frozen", False):
        if hasattr(sys, "_MEIPASS"):
            meipass_p = Path(sys._MEIPASS) / "assets" / "audio"
            if meipass_p.is_dir():
                return meipass_p
        exe_p = Path(sys.executable).resolve().parent / "assets" / "audio"
        if exe_p.is_dir():
            return exe_p
    return Path(__file__).resolve().parent.parent / "assets" / "audio"


class AudioManager:
    def __init__(self, assets_dir: Path | None = None) -> None:
        if not pygame.mixer.get_init():
            pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=1024)
            pygame.mixer.set_num_channels(8)

        base = assets_dir or get_default_assets_dir()
        self.assets_dir: Path = base
        self.sfx_dir: Path = base / "sfx"
        self.female_voice_dir: Path = base / "voice_female"
        self.male_voice_dir: Path = base / "voice_male"
        self.animals_dir: Path = base / "animals"

        self.current_voice: VoiceType = "FEMALE"
        self.current_language: LanguageType = "FR"
        self.available_languages: list[LanguageType] = ["FR"]

        self.channel_sfx: pygame.mixer.Channel = pygame.mixer.Channel(0)
        self.channel_voice: pygame.mixer.Channel = pygame.mixer.Channel(1)

        self._sfx_correct: pygame.mixer.Sound | None = None
        self._sfx_wrong: pygame.mixer.Sound | None = None
        self._load_sfx()

    def _load_sfx(self) -> None:
        correct_path = self.sfx_dir / "correct.mp3"
        wrong_path = self.sfx_dir / "wrong.wav"

        if correct_path.is_file():
            self._sfx_correct = pygame.mixer.Sound(str(correct_path))
        if wrong_path.is_file():
            self._sfx_wrong = pygame.mixer.Sound(str(wrong_path))

    def set_voice(self, voice: VoiceType) -> None:
        if voice not in ("FEMALE", "MALE"):
            raise ValueError(f"CRITICAL: Unknown voice '{voice}'. Must be 'FEMALE' or 'MALE'.")
        self.current_voice = voice

    def set_language(self, lang: LanguageType) -> None:
        if lang not in ("FR", "EN"):
            raise ValueError(f"CRITICAL: Unknown language '{lang}'. Must be 'FR' or 'EN'.")
        self.current_language = lang

    def set_available_languages(self, langs: list[LanguageType]) -> None:
        if not langs:
            raise ValueError("CRITICAL: available_languages cannot be empty.")
        self.available_languages = list(langs)

    def pick_random_voice(self) -> VoiceType:
        chosen: VoiceType = random.choice(["FEMALE", "MALE"])
        self.set_voice(chosen)
        return chosen

    def get_active_voice_dir(self) -> Path:
        if self.current_language == "EN":
            en_dir = self.assets_dir / "en"
            return en_dir / "voice_female" if self.current_voice == "FEMALE" else en_dir / "voice_male"
        return self.female_voice_dir if self.current_voice == "FEMALE" else self.male_voice_dir

    def resolve_audio_path(
        self,
        symbol: str,
        utterance_type: Literal["question", "ans_pos", "ans_neg"],
        prompt_mode: Literal["NAME", "PHONETIC"] = "NAME",
    ) -> Path:
        if not symbol or not symbol.strip():
            raise ValueError("CRITICAL: Symbol cannot be empty.")

        is_digit = symbol.strip().isdigit()
        if prompt_mode == "PHONETIC" and not is_digit:
            cat = "phonetic"
        else:
            cat = "number" if is_digit else "letter"

        # Normalize letters to uppercase for audio file lookup
        normalized_sym = symbol.strip() if is_digit else symbol.strip().upper()

        if utterance_type == "question":
            prefix = "q"
        elif utterance_type == "ans_pos":
            prefix = "ans_pos"
        elif utterance_type == "ans_neg":
            prefix = "ans_neg"
        else:
            raise ValueError(f"CRITICAL: Unknown utterance type '{utterance_type}'.")

        filename = f"{prefix}_{cat}_{normalized_sym}.mp3"
        return self.get_active_voice_dir() / filename

    def play_sfx_correct(self) -> None:
        if self._sfx_correct is not None:
            self.channel_sfx.play(self._sfx_correct)

    def play_sfx_wrong(self) -> None:
        if self._sfx_wrong is not None:
            self.channel_sfx.play(self._sfx_wrong)

    def play_voice(
        self,
        symbol: str,
        utterance_type: Literal["question", "ans_pos", "ans_neg"],
        prompt_mode: Literal["NAME", "PHONETIC"] = "NAME",
    ) -> bool:
        path = self.resolve_audio_path(symbol, utterance_type, prompt_mode=prompt_mode)
        if not path.is_file():
            # If phonetic clip is not yet generated, fall back to standard letter name clip
            if prompt_mode == "PHONETIC":
                fallback_path = self.resolve_audio_path(symbol, utterance_type, prompt_mode="NAME")
                if fallback_path.is_file():
                    sound = pygame.mixer.Sound(str(fallback_path))
                    self.channel_voice.play(sound)
                    return True
            raise FileNotFoundError(f"CRITICAL: Voice file not found at {path}")

        sound = pygame.mixer.Sound(str(path))
        self.channel_voice.play(sound)
        return True

    def is_voice_busy(self) -> bool:
        return self.channel_voice.get_busy()

    def play_animal_sound(self, score: int, language: LanguageType | None = None) -> bool:
        if not isinstance(score, int):
            raise TypeError(f"CRITICAL: score must be an int, got {type(score).__name__}")
        if score < 0 or score > 10:
            raise ValueError(f"CRITICAL: score must be between 0 and 10, got {score}")

        filename = SCORE_ANIMAL_AUDIO_MAP[score]
        chosen_lang = language
        if chosen_lang is None:
            if len(self.available_languages) > 1:
                chosen_lang = random.choice(self.available_languages)
            else:
                chosen_lang = self.current_language

        sub_dir = "fr" if chosen_lang == "FR" else "en"
        path = self.animals_dir / sub_dir / filename
        if not path.is_file():
            fallback_path = self.animals_dir / filename
            if fallback_path.is_file():
                path = fallback_path
            else:
                raise FileNotFoundError(f"CRITICAL: Animal sound file not found at {path}")

        sound = pygame.mixer.Sound(str(path))
        self.channel_voice.play(sound)
        return True

    def stop_all(self) -> None:
        self.channel_sfx.stop()
        self.channel_voice.stop()
