from pathlib import Path
import sys
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from src.config import (
    DEFAULT_LETTERS,
    DEFAULT_NUMBERS,
    GameConfig,
    load_config,
    save_config,
)


def test_config_defaults_and_validation() -> None:
    cfg = GameConfig()
    cfg.validate()
    assert set(DEFAULT_LETTERS).issubset(set(cfg.selected_symbols))
    assert set(DEFAULT_NUMBERS).issubset(set(cfg.selected_symbols))
    assert len(cfg.selected_symbols) >= 5
    assert cfg.lang_french is True
    assert cfg.lang_english is False


def test_config_validation_no_language_failure() -> None:
    cfg = GameConfig(lang_french=False, lang_english=False)
    with pytest.raises(ValueError, match="CRITICAL: At least one language"):
        cfg.validate()


def test_config_validation_both_languages_happy_path() -> None:
    cfg = GameConfig(lang_french=True, lang_english=True)
    cfg.validate()
    assert cfg.lang_french is True and cfg.lang_english is True


def test_config_validation_english_only_happy_path() -> None:
    cfg = GameConfig(lang_french=False, lang_english=True)
    cfg.validate()
    assert cfg.lang_french is False and cfg.lang_english is True


def test_config_validation_too_few_symbols() -> None:
    cfg = GameConfig(selected_symbols=["A", "B", "1"])
    with pytest.raises(ValueError, match="CRITICAL: At least 5 symbols must be selected"):
        cfg.validate()


def test_config_validation_invalid_symbol() -> None:
    cfg = GameConfig(selected_symbols=["A", "B", "C", "D", "INVALID_SYM"])
    with pytest.raises(ValueError, match="CRITICAL: Unknown symbol"):
        cfg.validate()


def test_save_and_load_config(tmp_path: Path) -> None:
    config_file = tmp_path / "config.json"
    cfg = GameConfig(selected_symbols=["A", "B", "C", "1", "2"])
    saved_path = save_config(cfg, config_file)
    assert saved_path == config_file
    assert config_file.is_file()

    loaded = load_config(config_file)
    assert loaded.selected_symbols == ["A", "B", "C", "1", "2"]


def test_load_config_corrupt_json(tmp_path: Path) -> None:
    config_file = tmp_path / "corrupt.json"
    config_file.write_text("{invalid json", encoding="utf-8")
    with pytest.raises(ValueError, match="CRITICAL: Invalid configuration file"):
        load_config(config_file)


def test_get_user_config_dir_windows(monkeypatch: pytest.MonkeyPatch) -> None:
    from src.config import get_user_config_dir

    monkeypatch.setattr(sys, "platform", "win32")
    monkeypatch.setenv("APPDATA", "C:/MockAppData/Roaming")
    res = get_user_config_dir()
    assert res == Path("C:/MockAppData/Roaming/LaRouletteMagique")


def test_get_user_config_dir_darwin(monkeypatch: pytest.MonkeyPatch) -> None:
    from src.config import get_user_config_dir

    monkeypatch.setattr(sys, "platform", "darwin")
    res = get_user_config_dir()
    assert res == Path.home() / "Library" / "Application Support" / "LaRouletteMagique"


def test_get_user_config_dir_linux(monkeypatch: pytest.MonkeyPatch) -> None:
    from src.config import get_user_config_dir

    monkeypatch.setattr(sys, "platform", "linux")
    monkeypatch.setenv("XDG_CONFIG_HOME", "/mock/xdg/config")
    res = get_user_config_dir()
    assert res == Path("/mock/xdg/config/LaRouletteMagique")


def test_get_legacy_config_path_frozen(monkeypatch: pytest.MonkeyPatch) -> None:
    from src.config import get_legacy_config_path

    fake_exe = "C:/games/app.exe"
    monkeypatch.setattr(sys, "frozen", True, raising=False)
    monkeypatch.setattr(sys, "executable", fake_exe, raising=False)

    resolved = get_legacy_config_path()
    assert resolved == Path("C:/games/config.json")


def test_load_config_migrates_legacy_file(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    import src.config as config_mod

    legacy_dir = tmp_path / "legacy"
    legacy_dir.mkdir(parents=True)
    legacy_file = legacy_dir / "config.json"
    legacy_cfg = GameConfig(
        selected_symbols=["A", "B", "C", "D", "E"],
        ask_letter_names=False,
        ask_letter_sounds=True,
    )
    save_config(legacy_cfg, legacy_file)

    target_file = tmp_path / "appdata" / "LaRouletteMagique" / "config.json"

    monkeypatch.setattr(config_mod, "get_default_config_path", lambda: target_file)
    monkeypatch.setattr(config_mod, "get_legacy_config_path", lambda: legacy_file)

    loaded = config_mod.load_config()
    assert loaded.selected_symbols == ["A", "B", "C", "D", "E"]
    assert not loaded.ask_letter_names
    assert loaded.ask_letter_sounds
    assert target_file.is_file()


def test_load_config_migration_corrupt_legacy_raises(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    import src.config as config_mod

    legacy_file = tmp_path / "legacy" / "config.json"
    legacy_file.parent.mkdir(parents=True)
    legacy_file.write_text("{bad json", encoding="utf-8")

    target_file = tmp_path / "appdata" / "LaRouletteMagique" / "config.json"

    monkeypatch.setattr(config_mod, "get_default_config_path", lambda: target_file)
    monkeypatch.setattr(config_mod, "get_legacy_config_path", lambda: legacy_file)

    with pytest.raises(ValueError, match="CRITICAL: Invalid configuration file"):
        config_mod.load_config()


def test_load_config_non_list_symbols_raises(tmp_path: Path) -> None:
    config_file = tmp_path / "invalid_type.json"
    config_file.write_text('{"selected_symbols": "not-a-list"}', encoding="utf-8")
    with pytest.raises(ValueError, match="CRITICAL: 'selected_symbols' must be a list"):
        load_config(config_file)


def test_config_prompt_modes_validation() -> None:
    # Happy paths
    cfg_names = GameConfig(ask_letter_names=True, ask_letter_sounds=False)
    cfg_names.validate()
    cfg_sounds = GameConfig(ask_letter_names=False, ask_letter_sounds=True)
    cfg_sounds.validate()
    cfg_both = GameConfig(ask_letter_names=True, ask_letter_sounds=True)
    cfg_both.validate()

    # Failure path 1: Both prompt modes disabled
    cfg_none = GameConfig(ask_letter_names=False, ask_letter_sounds=False)
    with pytest.raises(ValueError, match="CRITICAL: At least one prompt mode"):
        cfg_none.validate()


def test_save_and_load_config_with_prompt_modes(tmp_path: Path) -> None:
    config_file = tmp_path / "config_modes.json"
    cfg = GameConfig(
        selected_symbols=["A", "B", "C", "1", "2"],
        ask_letter_names=False,
        ask_letter_sounds=True,
    )
    save_config(cfg, config_file)
    loaded = load_config(config_file)
    assert not loaded.ask_letter_names
    assert loaded.ask_letter_sounds


def test_config_distinct_case_insensitive_symbols() -> None:
    # 1 Happy path: 5 distinct letters plus lowercase variants is valid
    cfg_ok = GameConfig(selected_symbols=["A", "a", "B", "b", "C", "D", "E"])
    cfg_ok.validate()

    # 2 Failure path A: 5 symbols that are only 3 distinct letters (A/a, B/b, C) raises ValueError
    cfg_dup_case = GameConfig(selected_symbols=["A", "a", "B", "b", "C"])
    with pytest.raises(ValueError, match="CRITICAL: At least 5 symbols must be selected, got 3"):
        cfg_dup_case.validate()

    # 3 Failure path B: 6 symbols that are only 4 distinct letters raises ValueError
    cfg_four = GameConfig(selected_symbols=["A", "a", "B", "b", "C", "d"])
    with pytest.raises(ValueError, match="CRITICAL: At least 5 symbols must be selected, got 4"):
        cfg_four.validate()



