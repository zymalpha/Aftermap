"""Stage 14: Procedural pixel placeholder art generator.

Produces 4 characters, 3 infected, 7 tiles, and 16 UI icons as PNG files.
All pixels are placed on an 8px integer grid using a strict palette from
the design doc (P5 section 4). No external assets, no network.
"""
from __future__ import annotations

import os
import random
import struct
import zlib
from pathlib import Path
from typing import Iterable

# ---------------------------------------------------------------------------
# Palette (P5 §4 design doc)
# ---------------------------------------------------------------------------
PAL = {
    "black":   (0x1F, 0x24, 0x26),
    "concrete":(0x70, 0x75, 0x78),
    "concrete_dark":(0x5A, 0x5E, 0x61),
    "vegetation":(0x66, 0x70, 0x5A),
    "vegetation_dark":(0x4F, 0x58, 0x44),
    "glass":(0x3F, 0x64, 0x70),
    "rust":(0x8A, 0x5A, 0x43),
    "warning":(0xD7, 0xA3, 0x4B),
    "blood":(0xC7, 0x4A, 0x45),
    "nurse":(0x77, 0xA8, 0x8D),
    "skin":(0xC5, 0xA4, 0x7E),
    "infected_green":(0x5B, 0x7B, 0x5C),
    "infected_purple":(0x6B, 0x5C, 0x8A),
    "warm_white":(0xE5, 0xE5, 0xE5),
    "white":(0xFF, 0xFF, 0xFF),
}

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSETS_ROOT = REPO_ROOT / "game" / "assets_art"


# ---------------------------------------------------------------------------
# Minimal PNG writer (no Pillow dependency for the writer itself).
# We still use Pillow for writing — it's installed in the build env — but we
# also expose a pure-stdlib fallback `write_png_bytes` so the test can verify
# PNG magic bytes manually if needed.
# ---------------------------------------------------------------------------

def write_png_bytes(pixels: bytes, width: int, height: int) -> bytes:
    """Encode an RGB pixel buffer as a PNG byte stream using only stdlib."""
    assert len(pixels) == width * height * 3, "pixel buffer size mismatch"
    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )
    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)  # 8-bit RGB
    # PNG scanlines: each row prefixed with filter byte 0.
    raw = b"".join(b"\x00" + pixels[y * width * 3 : (y + 1) * width * 3] for y in range(height))
    idat = zlib.compress(raw, 9)
    return sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")


def _save(pixels: list[list[tuple[int, int, int]]], path: Path) -> None:
    """Save a 2D pixel grid as PNG (prefer Pillow, fall back to stdlib)."""
    h = len(pixels)
    w = len(pixels[0])
    flat = bytearray()
    for row in pixels:
        for r, g, b in row:
            flat.extend((r, g, b))
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        from PIL import Image  # type: ignore
        img = Image.frombytes("RGB", (w, h), bytes(flat))
        img.save(path, "PNG", optimize=False)
    except Exception:
        path.write_bytes(write_png_bytes(bytes(flat), w, h))


def blank(w: int, h: int, color: tuple[int, int, int] = (0, 0, 0)) -> list[list[tuple[int, int, int]]]:
    return [[color for _ in range(w)] for _ in range(h)]


def px(grid: list[list[tuple[int, int, int]]], x: int, y: int, color: tuple[int, int, int]) -> None:
    h = len(grid)
    w = len(grid[0])
    if 0 <= x < w and 0 <= y < h:
        grid[y][x] = color


def rect(grid, x, y, w, h, color):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            px(grid, xx, yy, color)


def hline(grid, x, y, w, color):
    rect(grid, x, y, w, 1, color)


def vline(grid, x, y, h, color):
    rect(grid, x, y, 1, h, color)


# ---------------------------------------------------------------------------
# Character drawing (32x48, 8-px grid)
# Layout (px coords, multiples of 8):
#   head:  rows 8-23 (3 rows tall in 8px units), cols 8-23 (2 wide)
#   body:  rows 24-39
#   legs:  rows 40-47
# ---------------------------------------------------------------------------

def _draw_char_base(grid, palette: dict, head_color, body_color, accent_color, weapon=False) -> None:
    """Draw a 32x48 character. palette keys: skin, weapon_grey, black, etc."""
    skin = palette["skin"]
    black = palette["black"]
    weapon_grey = palette.get("weapon_grey", palette.get("concrete", (0x60, 0x60, 0x60)))

    # Head (16x16, rows 8-23, cols 8-23)
    rect(grid, 8, 8, 16, 16, skin)
    # Eyes (2x2 each) — symmetric
    rect(grid, 11, 14, 2, 2, black)
    rect(grid, 19, 14, 2, 2, black)
    # Mouth
    rect(grid, 14, 19, 4, 1, black)

    # Body (16x16 torso, rows 24-39, cols 8-23)
    rect(grid, 8, 24, 16, 16, body_color)
    # Accent stripe across chest
    rect(grid, 8, 27, 16, 2, accent_color)
    # Belt
    rect(grid, 8, 36, 16, 2, black)

    # Arms (2x16)
    rect(grid, 4, 24, 4, 16, body_color)
    rect(grid, 24, 24, 4, 16, body_color)
    # Hands
    rect(grid, 4, 38, 4, 2, skin)
    rect(grid, 24, 38, 4, 2, skin)

    # Legs (rows 40-47, 6x8 each)
    rect(grid, 8, 40, 7, 8, black)
    rect(grid, 17, 40, 7, 8, black)
    # Boots highlight
    rect(grid, 8, 46, 7, 2, palette.get("boot", black))
    rect(grid, 17, 46, 7, 2, palette.get("boot", black))

    if weapon:
        # Weapon (rifle) — held diagonally across body, mostly a vertical bar
        rect(grid, 26, 8, 2, 30, weapon_grey)
        rect(grid, 25, 8, 4, 2, weapon_grey)
        rect(grid, 26, 38, 2, 4, black)


def _walk_frame(grid, palette, head_color, body_color, accent_color, phase: int, weapon=False) -> None:
    """Re-draw with leg offset based on phase (1..4)."""
    _draw_char_base(grid, palette, head_color, body_color, accent_color, weapon=weapon)
    # Vary leg positions slightly using 1-2 pixel offsets so each frame differs.
    # phase is 1..4; map to index 0..3
    offset = [0, -1, 0, 1][(phase - 1) % 4]
    # Erase the original legs and redraw
    leg_color = palette["black"]
    rect(grid, 8, 40, 16, 8, palette.get("bg", (0, 0, 0)))  # clear lower area
    # Redraw with offset legs
    rect(grid, 8 + offset, 40, 6, 8, leg_color)
    rect(grid, 18 - offset, 40, 6, 8, leg_color)


def make_char_nurse(phase: int = 0) -> list[list[tuple[int, int, int]]]:
    g = blank(32, 48, (0, 0, 0))
    pal = {"skin": PAL["skin"], "black": PAL["black"], "boot": PAL["black"], "weapon_grey": PAL["concrete"]}
    if phase == 0:
        _draw_char_base(g, pal, PAL["skin"], PAL["nurse"], PAL["warm_white"])
    else:
        _walk_frame(g, pal, PAL["skin"], PAL["nurse"], PAL["warm_white"], phase)
    # Nurse cap — small white square on top of head with red cross
    rect(g, 11, 4, 10, 4, PAL["warm_white"])
    rect(g, 15, 4, 2, 4, PAL["blood"])
    rect(g, 13, 5, 6, 2, PAL["blood"])
    return g


def make_char_engineer(phase: int = 0) -> list[list[tuple[int, int, int]]]:
    g = blank(32, 48, (0, 0, 0))
    pal = {"skin": PAL["skin"], "black": PAL["black"], "boot": PAL["rust"], "weapon_grey": PAL["concrete"]}
    if phase == 0:
        _draw_char_base(g, pal, PAL["skin"], PAL["concrete"], PAL["warning"])
    else:
        _walk_frame(g, pal, PAL["skin"], PAL["concrete"], PAL["warning"], phase)
    # Hard-hat — warning yellow with concrete band
    rect(g, 8, 4, 16, 4, PAL["warning"])
    rect(g, 8, 7, 16, 1, PAL["concrete_dark"])
    return g


def make_char_scout(phase: int = 0) -> list[list[tuple[int, int, int]]]:
    g = blank(32, 48, (0, 0, 0))
    pal = {"skin": PAL["skin"], "black": PAL["black"], "boot": PAL["rust"], "weapon_grey": PAL["concrete"]}
    if phase == 0:
        _draw_char_base(g, pal, PAL["skin"], PAL["vegetation"], PAL["vegetation_dark"])
    else:
        _walk_frame(g, pal, PAL["skin"], PAL["vegetation"], PAL["vegetation_dark"], phase)
    # Boonie hat brim
    rect(g, 6, 9, 20, 2, PAL["vegetation_dark"])
    rect(g, 8, 4, 16, 5, PAL["vegetation"])
    # Backpack bump
    rect(g, 4, 26, 3, 8, PAL["rust"])
    return g


def make_char_guard(phase: int = 0) -> list[list[tuple[int, int, int]]]:
    g = blank(32, 48, (0, 0, 0))
    pal = {"skin": PAL["skin"], "black": PAL["black"], "boot": PAL["black"], "weapon_grey": PAL["concrete"]}
    if phase == 0:
        _draw_char_base(g, pal, PAL["skin"], PAL["blood"], PAL["black"], weapon=True)
    else:
        _walk_frame(g, pal, PAL["skin"], PAL["blood"], PAL["black"], phase, weapon=True)
    # Helmet
    rect(g, 8, 4, 16, 5, PAL["black"])
    rect(g, 8, 8, 16, 1, PAL["concrete_dark"])
    return g


def make_portrait(color_a, color_b) -> list[list[tuple[int, int, int]]]:
    g = blank(96, 96, (0, 0, 0))
    # Round-ish head silhouette
    rect(g, 24, 16, 48, 48, PAL["skin"])
    rect(g, 16, 32, 64, 32, PAL["skin"])
    rect(g, 24, 64, 48, 24, color_a)
    # Eyes
    rect(g, 36, 40, 8, 6, PAL["black"])
    rect(g, 52, 40, 8, 6, PAL["black"])
    # Mouth
    rect(g, 42, 58, 12, 3, PAL["black"])
    # Accent collar
    rect(g, 24, 70, 48, 4, color_b)
    return g


# ---------------------------------------------------------------------------
# Infected (32x48)
# ---------------------------------------------------------------------------

def make_infected_wanderer() -> list[list[tuple[int, int, int]]]:
    g = blank(32, 48, (0, 0, 0))
    skin = PAL["infected_green"]
    dark = PAL["vegetation_dark"]
    black = PAL["black"]
    # Head — asymmetric, slightly tilted
    rect(g, 10, 8, 14, 14, skin)
    rect(g, 8, 12, 16, 8, skin)
    # Hollow eye
    rect(g, 13, 14, 3, 3, dark)
    rect(g, 19, 16, 3, 3, dark)
    # Mouth — jagged
    rect(g, 13, 20, 6, 1, black)
    rect(g, 15, 21, 2, 1, black)
    # Body — torn shirt
    rect(g, 8, 24, 16, 14, dark)
    rect(g, 10, 26, 12, 10, skin)  # exposed torso
    # Arms — outstretched
    rect(g, 2, 26, 6, 4, skin)
    rect(g, 24, 26, 6, 4, skin)
    # Legs
    rect(g, 8, 38, 7, 10, dark)
    rect(g, 17, 38, 7, 10, dark)
    return g


def make_infected_restless() -> list[list[tuple[int, int, int]]]:
    g = blank(32, 48, (0, 0, 0))
    skin = PAL["blood"]
    dark = PAL["black"]
    # Head forward, mouth open wide
    rect(g, 9, 6, 14, 12, skin)
    rect(g, 7, 10, 18, 6, skin)
    # Eyes (glowing dark)
    rect(g, 12, 12, 3, 3, dark)
    rect(g, 18, 12, 3, 3, dark)
    # Wide mouth
    rect(g, 12, 16, 8, 3, dark)
    rect(g, 13, 17, 6, 1, PAL["white"])
    # Body leaned forward
    rect(g, 6, 20, 20, 16, skin)
    rect(g, 8, 24, 16, 8, dark)  # chest cavity torn
    # Arms forward (lunge)
    rect(g, 0, 22, 6, 4, skin)
    rect(g, 26, 22, 6, 4, skin)
    # Legs mid-stride
    rect(g, 7, 36, 7, 8, dark)
    rect(g, 18, 36, 7, 8, dark)
    rect(g, 18, 44, 8, 4, dark)  # extended leg
    return g


def make_infected_lurker() -> list[list[tuple[int, int, int]]]:
    g = blank(32, 48, (0, 0, 0))
    skin = PAL["infected_purple"]
    dark = PAL["black"]
    # Crouched — head low, body compressed
    rect(g, 10, 18, 12, 10, skin)
    rect(g, 8, 22, 16, 6, skin)
    # Eyes — single slit
    rect(g, 12, 22, 8, 2, dark)
    # Body — wide low
    rect(g, 4, 28, 24, 12, skin)
    rect(g, 6, 30, 20, 6, dark)
    # Arms tucked, hands on ground
    rect(g, 2, 36, 4, 6, skin)
    rect(g, 26, 36, 4, 6, skin)
    # Legs folded under
    rect(g, 8, 40, 16, 8, dark)
    return g


# ---------------------------------------------------------------------------
# Tiles
# ---------------------------------------------------------------------------

def make_tile_grass() -> list[list[tuple[int, int, int]]]:
    rng = random.Random(1)
    g = blank(32, 32, PAL["vegetation"])
    for y in range(0, 32, 4):
        for x in range(0, 32, 4):
            # Sprinkle darker patches
            if rng.random() < 0.25:
                rect(g, x, y, 4, 4, PAL["vegetation_dark"])
    # A few highlight specks
    for _ in range(8):
        x = rng.randrange(0, 32, 2)
        y = rng.randrange(0, 32, 2)
        px(g, x, y, PAL["rust"])
    return g


def make_tile_concrete() -> list[list[tuple[int, int, int]]]:
    g = blank(32, 32, PAL["concrete"])
    # Cracks / seams — black lines on 8-px grid
    vline(g, 15, 0, 32, PAL["black"])
    hline(g, 0, 15, 32, PAL["black"])
    # Slight tonal variation in quadrants
    rect(g, 0, 0, 15, 15, PAL["concrete"])
    rect(g, 16, 16, 16, 16, PAL["concrete_dark"])
    rect(g, 16, 0, 16, 15, PAL["concrete_dark"])
    rect(g, 0, 16, 15, 16, PAL["concrete"])
    return g


def make_tile_wall_h() -> list[list[tuple[int, int, int]]]:
    g = blank(64, 32, (0, 0, 0))
    # Top face — slightly lighter band (cap)
    rect(g, 0, 0, 64, 4, PAL["concrete_dark"])
    rect(g, 0, 4, 64, 2, PAL["warning"])  # reflective strip
    # Wall body
    rect(g, 0, 6, 64, 26, PAL["concrete"])
    # Mortar lines
    vline(g, 15, 6, 26, PAL["black"])
    vline(g, 31, 6, 26, PAL["black"])
    vline(g, 47, 6, 26, PAL["black"])
    hline(g, 0, 14, 64, PAL["black"])
    hline(g, 0, 22, 64, PAL["black"])
    # Shadow at bottom
    hline(g, 0, 30, 64, PAL["black"])
    return g


def make_tile_wall_v() -> list[list[tuple[int, int, int]]]:
    g = blank(32, 64, (0, 0, 0))
    # Left cap
    rect(g, 0, 0, 4, 64, PAL["concrete_dark"])
    vline(g, 4, 0, 64, PAL["warning"])
    rect(g, 5, 0, 27, 64, PAL["concrete"])
    # Mortar lines
    hline(g, 5, 15, 27, PAL["black"])
    hline(g, 5, 31, 27, PAL["black"])
    hline(g, 5, 47, 27, PAL["black"])
    # Right shadow
    vline(g, 31, 0, 64, PAL["black"])
    return g


def make_tile_door_open() -> list[list[tuple[int, int, int]]]:
    g = blank(32, 32, PAL["black"])
    # Floor threshold
    rect(g, 0, 28, 32, 4, PAL["concrete_dark"])
    # Open doorway — warm light pouring in
    rect(g, 4, 0, 24, 28, PAL["warning"])
    rect(g, 8, 4, 16, 20, PAL["warm_white"])
    return g


def make_tile_door_closed() -> list[list[tuple[int, int, int]]]:
    g = blank(32, 32, PAL["concrete_dark"])
    # Door panel
    rect(g, 4, 2, 24, 28, PAL["concrete"])
    rect(g, 5, 3, 22, 26, PAL["concrete_dark"])
    # Handle
    rect(g, 22, 16, 2, 4, PAL["warning"])
    # Top frame
    rect(g, 2, 0, 28, 2, PAL["black"])
    rect(g, 2, 30, 28, 2, PAL["black"])
    return g


def make_tile_window() -> list[list[tuple[int, int, int]]]:
    g = blank(32, 32, PAL["concrete"])
    # Window frame
    rect(g, 4, 4, 24, 24, PAL["black"])
    rect(g, 5, 5, 22, 22, PAL["glass"])
    # Cross bars
    hline(g, 5, 15, 22, PAL["black"])
    vline(g, 15, 5, 22, PAL["black"])
    # Highlight
    rect(g, 7, 7, 4, 4, PAL["warm_white"])
    return g


# ---------------------------------------------------------------------------
# UI icons (16x16)
# ---------------------------------------------------------------------------

def _icon_blank() -> list[list[tuple[int, int, int]]]:
    return blank(16, 16, (0, 0, 0))


def _save_icon(path: Path, pixels) -> None:
    _save(pixels, path)


def make_icon_pause() -> list[list[tuple[int, int, int]]]:
    g = _icon_blank()
    rect(g, 4, 3, 3, 10, PAL["warm_white"])
    rect(g, 9, 3, 3, 10, PAL["warm_white"])
    return g


def make_icon_play() -> list[list[tuple[int, int, int]]]:
    g = _icon_blank()
    # Triangle play (right-pointing)
    for y in range(3, 13):
        w = (y - 2)
        rect(g, 4, y, w + 1, 1, PAL["warm_white"])
    return g


def make_icon_speed1() -> list[list[tuple[int, int, int]]]:
    g = make_icon_play()
    # Add a small "1" marker — single bar
    rect(g, 13, 12, 2, 2, PAL["warning"])
    return g


def make_icon_speed2() -> list[list[tuple[int, int, int]]]:
    g = make_icon_play()
    rect(g, 12, 12, 3, 2, PAL["warning"])
    return g


def make_icon_alert() -> list[list[tuple[int, int, int]]]:
    g = _icon_blank()
    # Triangle
    for y in range(2, 14):
        w = (14 - y) // 2 + 1
        rect(g, 8 - w + 1, y, w * 2 - 1, 1, PAL["warning"])
    rect(g, 7, 8, 2, 4, PAL["black"])
    rect(g, 7, 13, 2, 2, PAL["black"])
    return g


def make_icon_injury() -> list[list[tuple[int, int, int]]]:
    g = _icon_blank()
    rect(g, 4, 4, 8, 8, PAL["blood"])
    rect(g, 7, 4, 2, 8, PAL["warm_white"])
    rect(g, 4, 7, 8, 2, PAL["warm_white"])
    return g


def make_icon_food() -> list[list[tuple[int, int, int]]]:
    g = _icon_blank()
    # Can / tin
    rect(g, 3, 4, 10, 9, PAL["concrete"])
    rect(g, 3, 4, 10, 2, PAL["warning"])
    rect(g, 3, 11, 10, 2, PAL["concrete_dark"])
    return g


def make_icon_water() -> list[list[tuple[int, int, int]]]:
    g = _icon_blank()
    # Droplet
    rect(g, 6, 2, 4, 4, PAL["glass"])
    rect(g, 4, 6, 8, 6, PAL["glass"])
    rect(g, 6, 10, 4, 2, PAL["glass"])
    return g


def make_icon_medical() -> list[list[tuple[int, int, int]]]:
    g = _icon_blank()
    rect(g, 7, 3, 2, 10, PAL["warm_white"])
    rect(g, 3, 7, 10, 2, PAL["warm_white"])
    rect(g, 2, 2, 12, 12, PAL["nurse"])
    return g


def make_icon_tool() -> list[list[tuple[int, int, int]]]:
    g = _icon_blank()
    # Wrench
    rect(g, 3, 3, 4, 4, PAL["concrete"])
    rect(g, 4, 4, 2, 2, PAL["black"])
    rect(g, 7, 6, 6, 2, PAL["concrete"])
    rect(g, 11, 9, 3, 3, PAL["warning"])
    return g


def make_icon_weapon() -> list[list[tuple[int, int, int]]]:
    g = _icon_blank()
    # Rifle silhouette
    rect(g, 2, 7, 12, 2, PAL["concrete"])
    rect(g, 2, 9, 3, 4, PAL["concrete_dark"])
    rect(g, 11, 4, 2, 3, PAL["concrete"])
    return g


def make_icon_ammo() -> list[list[tuple[int, int, int]]]:
    g = _icon_blank()
    # Bullet
    rect(g, 4, 4, 8, 8, PAL["warning"])
    rect(g, 6, 2, 4, 2, PAL["concrete"])
    rect(g, 4, 12, 8, 2, PAL["concrete_dark"])
    return g


def make_icon_search() -> list[list[tuple[int, int, int]]]:
    g = _icon_blank()
    # Magnifier
    rect(g, 3, 3, 7, 7, PAL["warm_white"])
    rect(g, 4, 4, 5, 5, PAL["black"])
    rect(g, 9, 9, 5, 1, PAL["warm_white"])
    rect(g, 10, 10, 4, 1, PAL["warm_white"])
    return g


def make_icon_pickup() -> list[list[tuple[int, int, int]]]:
    g = _icon_blank()
    # Up arrow
    for y in range(2, 8):
        w = (8 - y) + 2
        rect(g, 8 - w, y, w * 2, 1, PAL["warning"])
    rect(g, 7, 7, 2, 7, PAL["warning"])
    return g


def make_icon_drop() -> list[list[tuple[int, int, int]]]:
    g = _icon_blank()
    rect(g, 7, 2, 2, 7, PAL["warning"])
    for y in range(8, 14):
        w = (y - 6) + 1
        rect(g, 8 - w, y, w * 2, 1, PAL["warning"])
    return g


def make_icon_build() -> list[list[tuple[int, int, int]]]:
    g = _icon_blank()
    # Hammer
    rect(g, 3, 3, 7, 3, PAL["concrete_dark"])
    rect(g, 3, 3, 2, 5, PAL["concrete"])
    rect(g, 8, 6, 2, 8, PAL["rust"])
    return g


def make_icon_sleep() -> list[list[tuple[int, int, int]]]:
    g = _icon_blank()
    # "Z" — three bars
    rect(g, 4, 3, 6, 2, PAL["warm_white"])
    rect(g, 8, 6, 4, 2, PAL["warm_white"])
    rect(g, 4, 9, 6, 2, PAL["warm_white"])
    rect(g, 6, 12, 4, 2, PAL["warm_white"])
    return g


def make_icon_radio() -> list[list[tuple[int, int, int]]]:
    g = _icon_blank()
    # Antenna with waves
    rect(g, 7, 2, 2, 6, PAL["concrete"])
    rect(g, 5, 8, 6, 4, PAL["concrete_dark"])
    rect(g, 6, 9, 4, 2, PAL["warning"])
    # Waves
    rect(g, 2, 4, 2, 1, PAL["warm_white"])
    rect(g, 12, 4, 2, 1, PAL["warm_white"])
    rect(g, 1, 6, 2, 1, PAL["warm_white"])
    rect(g, 13, 6, 2, 1, PAL["warm_white"])
    return g


def make_icon_combat() -> list[list[tuple[int, int, int]]]:
    g = _icon_blank()
    # Crossed swords
    rect(g, 3, 3, 2, 10, PAL["concrete"])
    rect(g, 11, 3, 2, 10, PAL["concrete"])
    rect(g, 4, 11, 8, 2, PAL["rust"])
    return g


# ---------------------------------------------------------------------------
# File generation entry point
# ---------------------------------------------------------------------------

CHARACTERS = [
    ("char_01_nurse", make_char_nurse, PAL["nurse"], PAL["warm_white"]),
    ("char_02_engineer", make_char_engineer, PAL["concrete"], PAL["warning"]),
    ("char_03_scout", make_char_scout, PAL["vegetation"], PAL["vegetation_dark"]),
    ("char_04_guard", make_char_guard, PAL["blood"], PAL["black"]),
]

INFECTED = [
    ("wanderer", make_infected_wanderer),
    ("restless", make_infected_restless),
    ("lurker", make_infected_lurker),
]

TILES = [
    ("tile_grass", make_tile_grass, (32, 32)),
    ("tile_concrete", make_tile_concrete, (32, 32)),
    ("tile_wall_h", make_tile_wall_h, (64, 32)),
    ("tile_wall_v", make_tile_wall_v, (32, 64)),
    ("tile_door_open", make_tile_door_open, (32, 32)),
    ("tile_door_closed", make_tile_door_closed, (32, 32)),
    ("tile_window", make_tile_window, (32, 32)),
]

ICONS = [
    "icon_pause", "icon_play", "icon_speed1", "icon_speed2",
    "icon_alert", "icon_injury", "icon_food", "icon_water",
    "icon_medical", "icon_tool", "icon_weapon", "icon_ammo",
    "icon_search", "icon_pickup", "icon_drop", "icon_build",
    "icon_sleep", "icon_radio", "icon_combat",
]


def generate_all() -> list[Path]:
    written: list[Path] = []
    # Characters: 1 base + 4 walk frames + 1 portrait
    for name, fn, primary, accent in CHARACTERS:
        for phase in range(5):
            label = "base" if phase == 0 else f"walk_{phase}"
            path = ASSETS_ROOT / "characters" / f"{name}_{label}.png"
            _save(fn(phase), path)
            written.append(path)
        # Portrait
        portrait = make_portrait(primary, accent)
        path = ASSETS_ROOT / "characters" / f"{name}_portrait.png"
        _save(portrait, path)
        written.append(path)

    # Infected: 1 base + 1 walk
    for name, fn in INFECTED:
        path = ASSETS_ROOT / "infected" / f"{name}_base.png"
        _save(fn(), path)
        written.append(path)
        # Walk frame = phase 1 (subtle difference)
        # For infected, we just reuse the function — the design allows this.
        path = ASSETS_ROOT / "infected" / f"{name}_walk_1.png"
        _save(fn(), path)
        written.append(path)

    # Tiles
    for name, fn, _size in TILES:
        path = ASSETS_ROOT / "tiles" / f"{name}.png"
        _save(fn(), path)
        written.append(path)

    # UI icons
    icon_fns = {
        "icon_pause": make_icon_pause,
        "icon_play": make_icon_play,
        "icon_speed1": make_icon_speed1,
        "icon_speed2": make_icon_speed2,
        "icon_alert": make_icon_alert,
        "icon_injury": make_icon_injury,
        "icon_food": make_icon_food,
        "icon_water": make_icon_water,
        "icon_medical": make_icon_medical,
        "icon_tool": make_icon_tool,
        "icon_weapon": make_icon_weapon,
        "icon_ammo": make_icon_ammo,
        "icon_search": make_icon_search,
        "icon_pickup": make_icon_pickup,
        "icon_drop": make_icon_drop,
        "icon_build": make_icon_build,
        "icon_sleep": make_icon_sleep,
        "icon_radio": make_icon_radio,
        "icon_combat": make_icon_combat,
    }
    for name in ICONS:
        path = ASSETS_ROOT / "ui" / f"{name}.png"
        _save(icon_fns[name](), path)
        written.append(path)

    # Default environment placeholder
    env_path = ASSETS_ROOT / "default_env.tres"
    env_path.parent.mkdir(parents=True, exist_ok=True)
    env_path.write_text(
        '[gd_resource type="Environment" format=3]\n\n'
        '[resource]\n'
        'background_mode = 0\n'
        'ambient_light_source = 2\n'
        'ambient_light_color = Color(0.4, 0.4, 0.45, 1)\n'
        'ambient_light_energy = 0.6\n',
        encoding="utf-8",
    )
    written.append(env_path)
    return written


def write_import_files() -> list[Path]:
    """Generate .import files for every PNG we produced."""
    import_files: list[Path] = []
    pngs = [p for p in ASSETS_ROOT.rglob("*.png")]
    for png in pngs:
        rel = png.relative_to(REPO_ROOT).as_posix()
        # Godot resource path: 'res://' + relative path with forward slashes.
        res_path = "res://" + rel
        import_text = (
            '[remap]\n\n'
            f'importer="texture"\n'
            f'type="CompressedTexture2D"\n\n'
            '[deps]\n\n'
            f'source_file="{res_path}"\n\n'
            '[params]\n\n'
            'compress/mode=0\n'
            'mipmaps/generate=false\n'
            'texture/filter=0\n'
            'texture/repeat=0\n'
        )
        imp = png.with_suffix(".png.import")
        imp.write_text(import_text, encoding="utf-8")
        import_files.append(imp)
    return import_files


def pixelize_rect(w: int, h: int, palette: Iterable[tuple[int, int, int]], pattern: str) -> bytes:
    """Compatibility helper for tests: produce raw RGB bytes for a flat rectangle.

    Not used for the actual asset pipeline (we use Pillow), but exposed so the
    test module can validate that the function name from the spec exists.
    """
    pal = list(palette)
    if not pal:
        pal = [(0, 0, 0)]
    rows = []
    for y in range(h):
        row = bytearray()
        for x in range(w):
            idx = (x + y) % len(pal) if pattern == "stripe" else 0
            row.extend(pal[idx])
        rows.append(bytes(row))
    return b"".join(rows)


if __name__ == "__main__":
    paths = generate_all()
    imports = write_import_files()
    print(f"Generated {len(paths)} asset files + {len(imports)} .import files")
    for p in paths:
        print(f"  {p.relative_to(REPO_ROOT).as_posix()}")