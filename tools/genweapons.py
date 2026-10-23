#!/usr/bin/env python3
"""Pack view-model PNGs → mode-E mask/image rows in src/weapon_spr.asm.

Each body cell and flash is baked at its real x, including the phase inside
the byte. Two hires bits become one colour-clock pixel. Bodies store the
inverted plane (ink %00, clear %11) and are ANDed on, so the gun is black.
Flashes store ink %11 / clear %00 and are ORed on (line colour).

    python tools/genweapons.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from sprmask import (  # noqa: E402
    CELL,
    H,
    W,
    bchunk,
    blit_cell,
    leftover_ink,
    load_png_1bit,
    pack_24x21,
    pack_window,
    pack_zeromask,
    parse_label_bytes,
    unpack_2x2,
    unpack_zeromask,
)

DOC = ROOT / "editor" / "quake64.json"
PNG_DIR = ROOT / "assets" / "weapons"
OUT = ROOT / "src" / "weapon_spr.asm"
SHEET = PNG_DIR / "sheet.png"

AXE_KEY = "axe"
EDIT_RE = re.compile(r"^([a-z0-9]+)_(\d+)_edit\.png$", re.I)

# label, png, viewport-relative hires x (VIC x − 88), dy added to weapon y.
# Same signed offset as wpn_flashdy / place_flash: −FLASH_DY, −FLASH_DY_GUN, FLASH_DY_NAIL.
FLASHES = [
    ("spr_muzzle_b", "muzzle_flash.png", 172 - 88, -20),
    ("spr_spark_b", "axe_flash.png", 172 - 88, -10),
    ("spr_nail_fl_b", "nail_flash_left.png", 160 - 88, -15),
    ("spr_nail_fr_b", "nail_flash_right.png", 184 - 88, -15),
]

# Weapon order in tables: axe, shot, nail, gren
WINDOWS = {
    "axe": [(14, 0), (13, 21), (24, 8)],
    "shot2": [(13, 0), (13, 21)],
    "nail": [(0, 0), (24, 0), (0, 21), (24, 21)],
    "rock": [(12, 0), (0, 21), (24, 21)],
}


def glob_edit_frames(key: str) -> list[int]:
    found: list[int] = []
    if not PNG_DIR.is_dir():
        return found
    for p in PNG_DIR.iterdir():
        m = EDIT_RE.match(p.name)
        if not m or m.group(1).lower() != key:
            continue
        found.append(int(m.group(2)))
    return sorted(set(found))


def item_frames(weapons: dict, key: str) -> list[int]:
    items = weapons.get("items") or weapons
    item = items.get(key) or {}
    raw = item.get("frames")
    if isinstance(raw, list) and raw:
        seen: set[int] = set()
        out: list[int] = []
        for f in raw:
            n = int(f)
            if n < 0 or n in seen:
                continue
            seen.add(n)
            out.append(n)
        return out
    found = glob_edit_frames(key)
    if found:
        return found
    return [0]


def edit_png(key: str, frame: int) -> Path:
    return PNG_DIR / f"{key}_{frame}_edit.png"


def pix_from_png(key: str, frame: int) -> list[list[int]] | None:
    path = edit_png(key, frame)
    if path.is_file():
        return load_png_1bit(path, W, H)
    return None


def pix_from_asm(label: str, windows: list[tuple[int, int]]) -> list[list[int]]:
    raw = parse_label_bytes(OUT, label)
    if len(raw) >= 256:
        return unpack_2x2(raw[:256])
    n = len(windows)
    if len(raw) < n * CELL:
        raise SystemExit(f"{label}: expected {n * CELL} occupancy bytes, got {len(raw)}")
    pix = [[0] * W for _ in range(H)]
    for i, (ox, oy) in enumerate(windows):
        blit_cell(pix, raw[i * CELL : (i + 1) * CELL], ox, oy)
    return pix


def load_pix(key: str, frame: int, label: str) -> list[list[int]]:
    path = edit_png(key, frame)
    pix = pix_from_png(key, frame)
    if pix is not None:
        print(f"  occupancy {key}: {path.name}")
        return pix
    raise SystemExit(f"occupancy needs {path} (not packed asm / unedited png)")


def cut_cells(key: str, pix: list[list[int]]) -> list[list[int]]:
    windows = WINDOWS[key]
    left = leftover_ink(pix, windows)
    if left:
        raise SystemExit(f"{key}: leftover ink {left[:20]}{'…' if len(left) > 20 else ''} ({len(left)})")
    return [pack_window(pix, ox, oy) for ox, oy in windows]


def flash_pix(png_name: str) -> list[list[int]]:
    path = PNG_DIR / png_name
    if not path.is_file():
        raise SystemExit(f"missing {path}")
    return load_png_1bit(path, 24, 21)


def write_sheet(rows: list[list[tuple[str, list[list[int]], list[tuple[int, int]]]]]) -> None:
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("Pillow not installed; skip PNG sheet")
        return
    pad = 8
    label_h = 16
    cols = max((len(row) for row in rows), default=1)
    img_w = cols * (W + pad) + pad
    img_h = len(rows) * (H + label_h + pad) + pad
    im = Image.new("RGB", (img_w, img_h), (12, 12, 14))
    draw = ImageDraw.Draw(im)
    try:
        font = ImageFont.load_default()
    except Exception:
        font = None
    y = pad
    for row in rows:
        x = pad
        for name, cells, windows in row:
            draw.text((x, y), name, fill=(212, 160, 23), font=font)
            pix = [[0] * W for _ in range(H)]
            for cell, (ox, oy) in zip(cells, windows):
                blit_cell(pix, cell, ox, oy)
            cell_im = Image.new("RGB", (W, H), (10, 10, 12))
            px = cell_im.load()
            for yy in range(H):
                for xx in range(W):
                    if pix[yy][xx]:
                        px[xx, yy] = (232, 228, 216)
            cy = y + label_h
            im.paste(cell_im, (x, cy))
            draw.rectangle((x - 1, cy - 1, x + W, cy + H), outline=(80, 70, 40))
            x += W + pad
        y += label_h + H + pad
    SHEET.parent.mkdir(parents=True, exist_ok=True)
    im.save(SHEET)
    print(f"Wrote {SHEET.relative_to(ROOT)}")


def bake_sprite(get_ink, ox: int, oy_store: int, *, black: bool = False) -> list[int]:
    """24×21 sprite whose left edge is hires column ox. oy_store is the signed dy.

    black: store the inverted plane (ink %00, clear %11) for an AND blit.
    Otherwise store ink %11, clear %00 for an ORA blit.
    """
    fat0 = ox >> 1
    fat1 = (ox + 23) >> 1
    b0 = fat0 >> 2
    b1 = fat1 >> 2
    width = b1 - b0 + 1
    plane: list[int] = []
    for ry in range(21):
        mask = [0xFF] * width
        image = [0] * width
        for px in range(24):
            if not get_ink(px, ry):
                continue
            fat = (ox + px) >> 1
            bi = (fat >> 2) - b0
            pair = 3 << ((3 - (fat & 3)) * 2)
            mask[bi] = (mask[bi] & ~pair) & 0xFF
            image[bi] = (image[bi] | pair) & 0xFF
        for m, im in zip(mask, image):
            if (m ^ im) != 0xFF or (m & im) != 0:
                raise SystemExit(f"bake phase broken at x={ox} row {ry}: {m:02x} {im:02x}")
        plane.extend(mask if black else image)
    yb = oy_store & 0xFF
    return [b0 & 0xFF, yb, width, 21, *plane]


def bake_windows(pix: list[list[int]], windows: list[tuple[int, int]]) -> list[int]:
    out = [len(windows)]

    def cell(ox: int, oy: int) -> list[int]:
        def get_ink(px: int, ry: int) -> int:
            x = ox + px
            y = oy + ry
            if 0 <= x < W and 0 <= y < H:
                return pix[y][x]
            return 0

        return bake_sprite(get_ink, ox, oy, black=True)

    for ox, oy in windows:
        out.extend(cell(ox, oy))
    return out


def bake_flash(pix: list[list[int]], ox: int, dy: int) -> list[int]:
    def get_ink(px: int, ry: int) -> int:
        if 0 <= px < 24 and 0 <= ry < 21:
            return pix[ry][px]
        return 0

    return [1, *bake_sprite(get_ink, ox, dy)]


def emit_bytes(label: str, data: list[int]) -> list[str]:
    return [label, bchunk(data).rstrip(), ""]


def main() -> None:
    if not DOC.is_file():
        raise SystemExit(f"missing {DOC}")
    doc = json.loads(DOC.read_text(encoding="utf-8"))
    weapons = doc.get("weapons") or {}

    shot_frames = item_frames(weapons, "shot2")
    nail_frames = item_frames(weapons, "nail")
    rock_frames = item_frames(weapons, "rock")
    axe_frames = item_frames(weapons, AXE_KEY)

    shot_pix = load_pix("shot2", shot_frames[0], "spr_shot2")
    rock_pix = load_pix("rock", rock_frames[0], "spr_rock")
    axe_pix = load_pix("axe", axe_frames[0], "spr_axe_0")
    nail_pix = [load_pix("nail", f, f"spr_nail_{f}") for f in nail_frames]
    if len(nail_pix) != 3:
        raise SystemExit(f"nail needs 3 frames, got {len(nail_pix)}")

    shot = cut_cells("shot2", shot_pix)
    rock = cut_cells("rock", rock_pix)
    axe = cut_cells("axe", axe_pix)
    nail = [cut_cells("nail", pix) for pix in nail_pix]

    # The blit uses the baked x_byte / y, phase included.
    axe_b = bake_windows(axe_pix, WINDOWS["axe"])
    shot_b = bake_windows(shot_pix, WINDOWS["shot2"])
    rock_b = bake_windows(rock_pix, WINDOWS["rock"])
    nail_b = [bake_windows(pix, WINDOWS["nail"]) for pix in nail_pix]
    flashes = [
        (label, bake_flash(flash_pix(png), ox, dy))
        for label, png, ox, dy in FLASHES
    ]

    parts = [
        "; Generated by tools/genweapons.py from assets/weapons — do not edit",
        "; Mode-E cells: count, then x_byte, y, width, height, plane.",
        "; Bodies are inverted (ink %00, clear %11) and the blit is AND, so the gun is black.",
        "; Flashes are ink %11 / clear %00. Phase 1 ORs line colour; phase 2 writes %10.",
        "",
        "; Frame pointers: axe, shot, nail0, nail1, nail2, rock.",
        "wpn_fr_lo",
        "\t!byte <spr_axe_b, <spr_shot_b, <spr_nail_b0, <spr_nail_b1, <spr_nail_b2, <spr_rock_b",
        "wpn_fr_hi",
        "\t!byte >spr_axe_b, >spr_shot_b, >spr_nail_b0, >spr_nail_b1, >spr_nail_b2, >spr_rock_b",
        "wpn_fr_base",
        "\t!byte 0, 1, 2, 5",
        "wpn_fl4_lo",
        "\t!byte <spr_spark_b, <spr_muzzle_b, <spr_nail_fl_b, <spr_muzzle_b",
        "wpn_fl4_hi",
        "\t!byte >spr_spark_b, >spr_muzzle_b, >spr_nail_fl_b, >spr_muzzle_b",
        "",
    ]
    parts += emit_bytes("spr_axe_b", axe_b)
    parts += emit_bytes("spr_shot_b", shot_b)
    parts += emit_bytes("spr_rock_b", rock_b)
    for i, data in enumerate(nail_b):
        parts += emit_bytes(f"spr_nail_b{i}", data)
    for label, data in flashes:
        parts += emit_bytes(label, data)

    OUT.write_text("\n".join(parts) + "\n", encoding="utf-8")
    print(f"Wrote {OUT.relative_to(ROOT)}")
    print(f"  axe {len(axe_b)}B  shot {len(shot_b)}B  rock {len(rock_b)}B")
    print(f"  nail: {len(nail_b)} frames, {len(nail_b[0]) if nail_b else 0}B")
    for label, data in flashes:
        print(f"  {label}: {len(data)}B")

    write_sheet(
        [
            [
                ("axe", axe, WINDOWS["axe"]),
                ("shot2", shot, WINDOWS["shot2"]),
                ("rock", rock, WINDOWS["rock"]),
            ],
            [(f"nail {i}", cells, WINDOWS["nail"]) for i, cells in enumerate(nail)],
        ]
    )


if __name__ == "__main__":
    main()
