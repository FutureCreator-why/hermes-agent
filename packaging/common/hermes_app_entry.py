"""PyInstaller entrypoint for packaged Hermes Agent apps."""

from __future__ import annotations

import os
import sys
from pathlib import Path


def _resource_root() -> Path:
    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        return Path(sys._MEIPASS)  # type: ignore[attr-defined]
    return Path(__file__).resolve().parents[2]


def _default_package_name() -> str:
    if sys.platform == "darwin":
        return "macos"
    if sys.platform == "win32":
        return "windows"
    if sys.platform.startswith("linux"):
        return "linux"
    return sys.platform


_RESOURCE_ROOT = _resource_root()
os.environ.setdefault("HERMES_LANG", "zh_CN")
os.environ.setdefault("LANG", "zh_CN.UTF-8")
os.environ.setdefault("HERMES_SKIP_WEB_BUILD", "1")
os.environ.setdefault("HERMES_BUNDLED_SKILLS", str(_RESOURCE_ROOT / "skills"))
os.environ.setdefault("HERMES_OPTIONAL_SKILLS", str(_RESOURCE_ROOT / "optional-skills"))
os.environ.setdefault("HERMES_PACKAGED", _default_package_name())

if sys.platform != "win32":
    os.environ.setdefault("LC_ALL", "zh_CN.UTF-8")


def main() -> None:
    from hermes_cli.main import main as hermes_main

    if len(sys.argv) == 1:
        sys.argv.extend(["dashboard"])
    hermes_main()


if __name__ == "__main__":
    main()
