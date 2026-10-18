#!/usr/bin/env python3
"""Simple wallpaper manager for Hyprland using `swww`.

Usage:
    wallpaper_manager.py <path-to-image>   # set a specific wallpaper
    wallpaper_manager.py random            # pick a random wallpaper
    wallpaper_manager.py restore           # re-apply the last wallpaper

Wallpapers are read from (in order):
    $WALLPAPER_DIR
    ~/.config/hypr/wallpapers
    ~/Pictures/Wallpapers
    ~/Pictures
The chosen wallpaper is remembered in
    ~/.cache/material-hyprland/last-wallpaper
so `restore` works across restarts.

Requires: swww (or hyprpaper as a fallback). Uses only the standard library.
"""

from __future__ import annotations

import os
import random
import subprocess
import sys
from pathlib import Path

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"}
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "material-hyprland"
LAST_FILE = CACHE_DIR / "last-wallpaper"


def candidate_dirs() -> list[Path]:
    env = os.environ.get("WALLPAPER_DIR")
    dirs = [Path(env)] if env else []
    dirs += [
        Path.home() / ".config" / "hypr" / "wallpapers",
        Path.home() / "Pictures" / "Wallpapers",
        Path.home() / "Pictures",
    ]
    return [d for d in dirs if d.is_dir()]


def gather_images() -> list[Path]:
    images: list[Path] = []
    for d in candidate_dirs():
        for f in d.iterdir():
            if f.is_file() and f.suffix.lower() in IMAGE_EXTS:
                images.append(f)
    return sorted(images)


def which(prog: str) -> bool:
    return subprocess.call(["sh", "-c", f"command -v {prog}"],
                           stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL) == 0


def apply_swww(path: Path) -> bool:
    if not which("swww"):
        return False
    subprocess.run(
        ["swww", "img", str(path),
         "--transition-type", "grow",
         "--transition-pos", "0.5,0.5",
         "--transition-duration", "1.2",
         "--transition-fps", "60"],
        check=False,
    )
    return True


def apply_hyprpaper(path: Path) -> bool:
    if not which("hyprpaper"):
        return False
    subprocess.run(["hyprctl", "hyprpaper", "preload", str(path)], check=False)
    subprocess.run(["hyprctl", "hyprpaper", "wallpaper", f",{path}"], check=False)
    return True


def apply(path: Path) -> None:
    if not path.is_file():
        sys.exit(f"wallpaper not found: {path}")
    ok = apply_swww(path) or apply_hyprpaper(path)
    if not ok:
        sys.exit("neither swww nor hyprpaper is installed")
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    LAST_FILE.write_text(str(path), encoding="utf-8")


def main(argv: list[str]) -> None:
    arg = argv[1] if len(argv) > 1 else "random"

    if arg == "restore":
        if LAST_FILE.is_file():
            apply(Path(LAST_FILE.read_text().strip()))
        else:
            main(["", "random"])
        return

    if arg == "random":
        images = gather_images()
        if not images:
            sys.exit("no wallpapers found; set WALLPAPER_DIR or add images to ~/Pictures/Wallpapers")
        apply(random.choice(images))
        return

    apply(Path(arg).expanduser())


if __name__ == "__main__":
    main(sys.argv)
