from pathlib import Path
import pytest


@pytest.fixture(autouse=True)
def isolate_user_config(monkeypatch: pytest.MonkeyPatch, tmp_path: Path, request: pytest.FixtureRequest) -> None:
    if request.node.name.startswith("test_get_user_config_dir") or request.node.name.startswith("test_get_legacy_config_path"):
        return

    fake_appdata = tmp_path / "appdata"
    fake_appdata.mkdir(parents=True, exist_ok=True)
    try:
        import src.config as cfg_mod
    except ImportError:
        return

    monkeypatch.setattr(cfg_mod, "get_user_config_dir", lambda: fake_appdata / "LaRouletteMagique")
    monkeypatch.setattr(
        cfg_mod,
        "get_legacy_config_path",
        lambda: tmp_path / "legacy" / "config.json",
    )
