#!/usr/bin/env python3
"""Simple wallpaper manager for Hyprland using `swww`.

Usage:
    wallpaper_manager.py <path-to-image>   # set a specific wallpaper
    wallpaper_manager.py random            # pick a random wallpaper
    wallpaper_manager.py restore           # re-apply the last wallpaper
    wallpaper_manager.py list              # print every wallpaper path (one per line)
    wallpaper_manager.py current           # print the active wallpaper path
    wallpaper_manager.py blur [on|off|toggle]     # query or set wallpaper blur
Options (may prefix any action):
    --blur / --no-blur                     # enable/disable blur for this run

Wallpapers are read from (in order):
    $WALLPAPER_DIR
    ~/.config/hypr/wallpapers
    ~/Pictures/Wallpapers
    ~/Pictures
The chosen wallpaper is remembered in
    ~/.cache/material-hyprland/last-wallpaper
so `restore` works across restarts.

The colour-scheme mode (dark/light) is persisted in
    ${XDG_STATE_HOME:-~/.local/state}/theme/mode
and reused by `apply-theme.sh`, so a wallpaper change keeps the mode the user
picked in the shell settings.

Requires: swww/awww (the `*-daemon` is started on demand if needed) or
hyprpaper. Uses only the standard library.
"""

from __future__ import annotations

import os
import random
import subprocess
import sys
import time
from pathlib import Path

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"}
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "material-hyprland"
LAST_FILE = CACHE_DIR / "last-wallpaper"
BLUR_FILE = CACHE_DIR / "wallpaper-blur"
BLUR_CACHE = CACHE_DIR / "blurred"
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state")) / "theme"
MODE_FILE = STATE_DIR / "mode"

# Gaussian blur radius used when the "blur wallpaper" option is enabled.
BLUR_RADIUS = int(os.environ.get("WALLPAPER_BLUR_RADIUS", "32"))
BLUR_SIGMA = os.environ.get("WALLPAPER_BLUR_SIGMA", "4")


def persisted_mode() -> str | None:
    """Return the shell-selected theme mode (dark/light), if any."""
    try:
        mode = MODE_FILE.read_text(encoding="utf-8").strip()
    except OSError:
        return None
    return mode if mode in ("dark", "light") else None


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


def blur_enabled() -> bool:
    """Return whether the user has the "blur wallpaper" option enabled."""
    try:
        return BLUR_FILE.read_text(encoding="utf-8").strip() == "1"
    except OSError:
        return False


def set_blur(enabled: bool) -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    BLUR_FILE.write_text("1" if enabled else "0", encoding="utf-8")


def blurred_variant(path: Path) -> Path | None:
    """Return a blurred copy of *path* (cached), or None if unavailable.

    Uses ImageMagick (``magick``/``convert``). The blurred file is cached under
    the per-user cache dir keyed by the source path, so re-applying the same
    wallpaper is instant.
    """
    tool = "magick" if which("magick") else ("convert" if which("convert") else None)
    if tool is None:
        return None
    BLUR_CACHE.mkdir(parents=True, exist_ok=True)
    # Key by a hash of the absolute source path + its mtime so it refreshes
    # if the file is replaced.
    try:
        stamp = int(path.stat().st_mtime)
    except OSError:
        stamp = 0
    import hashlib  # local: only needed here
    key = hashlib.sha1(f"{path.resolve()}::{stamp}::{BLUR_RADIUS}::{BLUR_SIGMA}".encode()).hexdigest()[:16]
    out = BLUR_CACHE / f"blur-{key}{path.suffix or '.png'}"
    if out.is_file() and out.stat().st_size > 0:
        return out
    cmd = [tool, str(path), "-blur", f"0x{BLUR_SIGMA}",
           "-resize", "2560x2560>", str(out)]
    rc = subprocess.run(cmd, capture_output=True, text=True).returncode
    if rc != 0 or not out.is_file():
        return None
    return out


def regenerate_theme(path: Path) -> None:
    """Regenerate the matugen terminal palette from the new wallpaper.

    Best-effort: a missing matugen or a failed run never blocks the wallpaper
    change. The helper lives next to this script after installation.
    """
    here = Path(__file__).resolve().parent
    helper = here / "apply-theme.sh"
    if not helper.is_file():
        return
    # Prefer the mode the shell persisted; fall back to $THEME_MODE, then dark.
    mode = os.environ.get("THEME_MODE") or persisted_mode() or "dark"
    subprocess.run([str(helper), str(path), f"--mode={mode}"], check=False)


def swww_client() -> str | None:
    """Return the swww client binary name.

    The project was renamed from ``swww`` to ``awww``; new installs only ship
    the ``awww``/``awww-daemon`` names. Accept either so old and new packages
    both work.
    """
    for name in ("awww", "swww"):
        if which(name):
            return name
    return None


def apply_swww(path: Path) -> bool:
    client = swww_client()
    if client is None:
        return False
    daemon = f"{client}-daemon"
    if not which(daemon):
        return False
    # The daemon may not be running even if the binary exists; ``query`` fails
    # in that case. Start it lazily so a fresh session self-heals.
    if subprocess.run([client, "query"], stdout=subprocess.DEVNULL,
                      stderr=subprocess.DEVNULL).returncode != 0:
        subprocess.Popen([daemon], stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
        # Give it a moment to create its socket.
        for _ in range(20):
            if subprocess.run([client, "query"], stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL).returncode == 0:
                break
            time.sleep(0.1)
        else:
            return False
    img = subprocess.run(
        [client, "img", str(path),
         "--transition-type", "grow",
         "--transition-pos", "0.5,0.5",
         "--transition-duration", "1.2",
         "--transition-fps", "60"],
        capture_output=True, text=True,
    )
    if img.returncode != 0:
        return False
    # Confirm the compositor is actually displaying our image.
    query = subprocess.run([client, "query"], capture_output=True, text=True)
    return query.returncode == 0 and query.stdout.strip() != ""


def apply_hyprpaper(path: Path) -> bool:
    """Drive hyprpaper through its config file.

    hyprpaper v0.8.x moved to a block-style config and its runtime ``hyprctl
    hyprpaper`` IPC is unreliable against current Hyprland, so we rewrite
    ~/.config/hypr/hyprpaper.conf with a concrete target and restart the daemon
    once to load it.
    """
    if not which("hyprpaper"):
        return False
    conf = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "hypr" / "hyprpaper.conf"
    conf.parent.mkdir(parents=True, exist_ok=True)
    # Use the monitor hyprctl reports (fall back to preloading for all outputs).
    monitor = ""
    try:
        monitors = subprocess.run(["hyprctl", "monitors", "-j"],
                                  capture_output=True, text=True).stdout
        import json  # local: only needed here
        data = json.loads(monitors) if monitors.strip() else []
        if data:
            monitor = data[0].get("name", "")
    except Exception:
        monitor = ""

    target = monitor or ""
    conf.write_text(
        "splash = false\n"
        "ipc = on\n"
        f"preload = {path}\n"
        f"wallpaper = {target},{path}\n",
        encoding="utf-8",
    )
    # Restart the daemon so it reads the rewritten config.
    subprocess.run(["pkill", "-x", "hyprpaper"], capture_output=True)
    time.sleep(0.2)
    subprocess.Popen(["hyprpaper"], stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)
    time.sleep(0.6)
    probe = subprocess.run(["hyprctl", "hyprpaper", "listactive"],
                           capture_output=True, text=True)
    return probe.returncode == 0


def apply(path: Path) -> None:
    if not path.is_file():
        sys.exit(f"wallpaper not found: {path}")

    # When blur is enabled, display a blurred derivative but keep the original
    # as the "current" wallpaper (and for theme sampling below).
    display = path
    if blur_enabled():
        blurred = blurred_variant(path)
        if blurred is not None:
            display = blurred
        else:
            # Blur requested but no ImageMagick available: fall back to sharp
            # rather than failing the whole apply.
            print("wallpaper: blur requested but ImageMagick (magick/convert) "
                  "not found; showing the original", file=sys.stderr)

    ok = apply_swww(display) or apply_hyprpaper(display)
    if not ok:
        sys.exit(
            "could not apply wallpaper: no working backend found.\n"
            "  - swww/awww: install it (provides *-daemon) and let it run\n"
            "  - or hyprpaper: install it (added to execs.conf)"
        )
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    LAST_FILE.write_text(str(path), encoding="utf-8")
    # Keep the terminal palette in sync with the wallpaper (sample the original
    # so the palette stays vivid even when the displayed copy is blurred).
    regenerate_theme(path)


def main(argv: list[str]) -> None:
    # Split out leading options so ``--blur``/``--no-blur`` can prefix any action.
    args = argv[1:]
    force_blur: bool | None = None
    rest: list[str] = []
    for a in args:
        if a == "--blur":
            force_blur = True
        elif a == "--no-blur":
            force_blur = False
        else:
            rest.append(a)

    if force_blur is not None:
        set_blur(force_blur)

    arg = rest[0] if rest else "random"

    if arg == "list":
        # One absolute path per line; consumed by the in-shell wallpaper picker.
        for image in gather_images():
            print(image)
        return

    if arg == "current":
        if LAST_FILE.is_file():
            print(LAST_FILE.read_text(encoding="utf-8").strip())
        return

    if arg == "restore":
        if LAST_FILE.is_file():
            apply(Path(LAST_FILE.read_text().strip()))
        else:
            main(["", "random"])
        return

    if arg == "blur":
        # ``blur`` (query) | ``blur on|off|toggle``. A state *change* re-applies
        # the current wallpaper so it takes effect immediately; a plain query
        # only prints the state.
        sub = rest[1] if len(rest) > 1 else ""
        changed = True
        if sub == "on":
            set_blur(True)
        elif sub == "off":
            set_blur(False)
        elif sub == "toggle":
            set_blur(not blur_enabled())
        elif sub == "":
            changed = False
        else:
            sys.exit("usage: wallpaper_manager.py blur [on|off|toggle]")
        print("on" if blur_enabled() else "off")
        if changed and LAST_FILE.is_file():
            apply(Path(LAST_FILE.read_text().strip()))
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


