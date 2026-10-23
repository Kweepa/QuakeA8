"""Enhanced-density ATR: boot, 16-byte directory, CBM payloads."""

from __future__ import annotations

import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "quakea8.atr"

SECTOR = 128
SECTORS = 1040
DIR_SEC = 20
DIR_SECS = 4
ENTRY = 16
# Quicksave slot: the last QSAVE_N sectors of the disk, outside the file area.
# src/mem.asm QSAVE_SEC / QSAVE_N must match (checked below).
QSAVE_N = 5
QSAVE_SEC = SECTORS - QSAVE_N + 1

FILES = [
    ("EDATA", ROOT / "enemydata.prg", None),
    ("GAME", ROOT / "game.prg", None),
    ("SQT", ROOT / "sqt.prg", None),
    ("FNT", ROOT / "fnt.prg", 2 + 1024),
    ("TAB", ROOT / "tab.prg", None),
    ("MENU", ROOT / "menu.prg", None),
    ("QSAVE", ROOT / "qsave.prg", None),
] + [(f"E1M{i}", ROOT / "maps" / f"e1m{i}.prg", None) for i in range(1, 8)] + [
    ("GRUNT", ROOT / "enemies" / "grunt.prg", None),
    ("KNIGHT", ROOT / "enemies" / "knight.prg", None),
    ("ROTT", ROOT / "enemies" / "rott.prg", None),
    ("SCRAG", ROOT / "enemies" / "scrag.prg", None),
    ("OGRE", ROOT / "enemies" / "ogre.prg", None),
    ("SHAMBL", ROOT / "enemies" / "shambl.prg", None),
    ("CHTHON", ROOT / "enemies" / "chthon.prg", None),
    ("ZOMBIE", ROOT / "enemies" / "zombie.prg", None),
    ("DEMON", ROOT / "enemies" / "demon.prg", None),
    ("CRUSH", ROOT / "enemies" / "crush.prg", None),
]


def main() -> None:
    boot_path = ROOT / "src" / "a8boot.bin"
    boot = bytearray(boot_path.read_bytes())
    if len(boot) < 6 or boot[2:4] != b"\x00\x04":
        raise SystemExit(f"bad boot image {boot_path} ({len(boot)} bytes)")
    nsec = math.ceil(len(boot) / SECTOR)
    if nsec >= DIR_SEC:
        raise SystemExit(f"boot is {nsec} sectors, directory starts at {DIR_SEC}")
    boot = boot.ljust(nsec * SECTOR, b"\x00")
    boot[1] = 1
    lbl = (ROOT / "src" / "a8boot.lbl").read_text(encoding="utf-8", errors="replace")
    mark = None
    for line in lbl.splitlines():
        if ".stage_nsec" in line:
            mark = int(line.split()[1].split(":")[1], 16)
            break
    if mark is None:
        raise SystemExit("stage_nsec missing from src/a8boot.lbl")
    boot[mark - 0x400] = nsec - 1

    blobs: list[tuple[str, bytes]] = []
    for name, path, cap in FILES:
        if len(name) > 8:
            raise SystemExit(f"name too long: {name}")
        if not path.is_file():
            raise SystemExit(f"missing {path}")
        data = path.read_bytes()
        if cap is not None:
            data = data[:cap]
        blobs.append((name, data))
    if len(blobs) > DIR_SECS * SECTOR // ENTRY - 1:
        raise SystemExit("directory overflow")

    data_sec = DIR_SEC + DIR_SECS
    directory = bytearray(DIR_SECS * SECTOR)
    cursor = data_sec
    payload = bytearray()
    for i, (name, data) in enumerate(blobs):
        off = i * ENTRY
        raw = name.encode("ascii")
        directory[off : off + len(raw)] = raw
        count = math.ceil(len(data) / SECTOR)
        directory[off + 8] = cursor & 0xFF
        directory[off + 9] = (cursor >> 8) & 0xFF
        directory[off + 10] = count & 0xFF
        directory[off + 11] = (count >> 8) & 0xFF
        directory[off + 12] = len(data) & 0xFF
        directory[off + 13] = (len(data) >> 8) & 0xFF
        payload += data
        pad = (-len(data)) % SECTOR
        payload += b"\x00" * pad
        cursor += count

    used = (cursor - 1)
    if used >= QSAVE_SEC:
        raise SystemExit(
            f"ATR overflow: files end at sector {used}, quicksave slot starts at {QSAVE_SEC}"
        )
    mem = (ROOT / "src" / "mem.asm").read_text(encoding="utf-8", errors="replace")
    for sym, want in (("QSAVE_SEC", QSAVE_SEC), ("QSAVE_N", QSAVE_N)):
        m = re.search(rf"^{sym}\s*=\s*(\d+)", mem, re.M)
        if not m or int(m.group(1)) != want:
            raise SystemExit(f"src/mem.asm {sym} must be {want}")

    image = bytearray(SECTORS * SECTOR)
    image[: len(boot)] = boot
    dir_off = (DIR_SEC - 1) * SECTOR
    image[dir_off : dir_off + len(directory)] = directory
    file_off = (data_sec - 1) * SECTOR
    image[file_off : file_off + len(payload)] = payload

    paras = (SECTORS * SECTOR) // 16
    header = bytearray(16)
    header[0] = 0x96
    header[1] = 0x02
    header[2] = paras & 0xFF
    header[3] = (paras >> 8) & 0xFF
    header[4] = SECTOR & 0xFF
    header[5] = (SECTOR >> 8) & 0xFF
    OUT.write_bytes(header + image)
    print(f"wrote {OUT}  boot={nsec} sectors  files={len(blobs)}  last={used}")


if __name__ == "__main__":
    main()
