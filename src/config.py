from dataclasses import dataclass, field
import json
import os
from pathlib import Path
import sys

DEFAULT_LETTERS: list[str] = ["A", "O", "U", "I", "E"]
DEFAULT_NUMBERS: list[str] = ["1", "2", "3", "4", "5", "6"]
ALL_UPPERCASE: list[str] = [chr(c) for c in range(ord("A"), ord("Z") + 1)]
ALL_LOWERCASE: list[str] = [chr(c) for c in range(ord("a"), ord("z") + 1)]
ALL_NUMBERS: list[str] = [str(n) for n in range(1, 21)]

MIN_SELECTED_SYMBOLS: int = 5


@dataclass
class GameConfig:
    selected_symbols: list[str] = field(
        default_factory=lambda: list(DEFAULT_LETTERS + DEFAULT_NUMBERS)
    )
    ask_letter_names: bool = True
    ask_letter_sounds: bool = False
    lang_french: bool = True
    lang_english: bool = False

    def validate(self) -> None:
        if not self.ask_letter_names and not self.ask_letter_sounds:
            raise ValueError(
                "CRITICAL: At least one prompt mode (names or sounds) must be selected."
            )
        if not self.lang_french and not self.lang_english:
            raise ValueError(
                "CRITICAL: At least one language (French or English) must be selected."
            )
        distinct_symbols = {s.upper() for s in self.selected_symbols}
        if len(distinct_symbols) < MIN_SELECTED_SYMBOLS:
            raise ValueError(
                f"CRITICAL: At least {MIN_SELECTED_SYMBOLS} symbols must be selected, "
                f"got {len(distinct_symbols)}."
            )
        valid_pool = set(ALL_UPPERCASE + ALL_LOWERCASE + ALL_NUMBERS)
        for sym in self.selected_symbols:
            if sym not in valid_pool:
                raise ValueError(f"CRITICAL: Unknown symbol '{sym}' in selected_symbols.")

def get_user_config_dir() -> Path:
    if sys.platform == "win32":
        appdata = os.environ.get("APPDATA")
        base = Path(appdata) if appdata else Path.home() / "AppData" / "Roaming"
        return base / "LaRouletteMagique"
    elif sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "LaRouletteMagique"
    else:
        xdg = os.environ.get("XDG_CONFIG_HOME")
        base = Path(xdg) if xdg else Path.home() / ".config"
        return base / "LaRouletteMagique"


def get_legacy_config_path() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent / "config.json"
    return Path(__file__).resolve().parent.parent / "config.json"


def get_default_config_path(base_dir: Path | None = None) -> Path:
    if base_dir is not None:
        return base_dir / "config.json"
    return get_user_config_dir() / "config.json"


def _read_config_file(path: Path) -> GameConfig:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        symbols = data.get("selected_symbols")
        if not isinstance(symbols, list):
            raise ValueError("CRITICAL: 'selected_symbols' must be a list in config.json.")
        ask_names = bool(data.get("ask_letter_names", True))
        ask_sounds = bool(data.get("ask_letter_sounds", False))
        lang_fr = bool(data.get("lang_french", True))
        lang_en = bool(data.get("lang_english", False))
        cfg = GameConfig(
            selected_symbols=[str(s) for s in symbols],
            ask_letter_names=ask_names,
            ask_letter_sounds=ask_sounds,
            lang_french=lang_fr,
            lang_english=lang_en,
        )
        cfg.validate()
        return cfg
    except (json.JSONDecodeError, ValueError) as err:
        raise ValueError(f"CRITICAL: Invalid configuration file at {path}: {err}") from err


def load_config(config_path: Path | None = None) -> GameConfig:
    path = config_path or get_default_config_path()
    if not path.is_file():
        # Check for legacy config file to migrate settings forward
        if config_path is None:
            legacy_path = get_legacy_config_path()
            if legacy_path.is_file() and legacy_path.resolve() != path.resolve():
                cfg = _read_config_file(legacy_path)
                save_config(cfg, path)
                return cfg

        cfg = GameConfig()
        save_config(cfg, path)
        return cfg

    return _read_config_file(path)


def save_config(cfg: GameConfig, config_path: Path | None = None) -> Path:
    cfg.validate()
    path = config_path or get_default_config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "selected_symbols": cfg.selected_symbols,
        "ask_letter_names": cfg.ask_letter_names,
        "ask_letter_sounds": cfg.ask_letter_sounds,
        "lang_french": cfg.lang_french,
        "lang_english": cfg.lang_english,
    }
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return path
