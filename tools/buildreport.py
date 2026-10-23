#!/usr/bin/env python3
"""Write build-report.json for the editor Build tab.

Success replaces the file. --failed STEP keeps the previous sections and
stamps ok/step/time so a broken build still names the command that died.
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
from datetime import datetime
from pathlib import Path

from checkheap import heap_report
from genaibanks import DOS_NAMES, ENEMY_BANK_MAX, HEADER_SIZE, MAGIC
from memoryreport import module_report
from mkatr import DIR_SEC, DIR_SECS, ENTRY, OUT as ATR_PATH, SECTOR, SECTORS

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build-report.json"
ENEMY_DIR = ROOT / "enemies"


def now() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


def atr_listing(path: Path) -> dict:
    """Directory of quakea8.atr. `blocks` is the sector count the boot loader uses."""
    if not path.is_file():
        raise SystemExit(f"missing: {path}")
    image = path.read_bytes()[16:]
    dir_off = (DIR_SEC - 1) * SECTOR
    directory = image[dir_off : dir_off + DIR_SECS * SECTOR]
    files: list[dict[str, int | str]] = []
    used = DIR_SEC + DIR_SECS - 1
    for i in range(len(directory) // ENTRY):
        ent = directory[i * ENTRY : (i + 1) * ENTRY]
        if ent[0] == 0:
            break
        name = ent[:8].split(b"\x00", 1)[0].decode("ascii", errors="replace")
        start = ent[8] | (ent[9] << 8)
        count = ent[10] | (ent[11] << 8)
        files.append({"name": name, "blocks": count})
        used = max(used, start + count - 1)
    return {
        "name": path.name,
        "free": SECTORS - used,
        "unit": "sectors",
        "files": files,
    }


def read_bank(path: Path, name: str) -> dict:
    raw = path.read_bytes()
    if len(raw) < 2 + HEADER_SIZE:
        raise SystemExit(f"{path}: too short")
    payload = raw[2:]
    magic, code_n, rel_n, map_n, _entry, pose_off = struct.unpack_from(
        "<4sHHHHH", payload, 0
    )
    if magic != MAGIC:
        raise SystemExit(f"{path}: bad magic {magic!r}")
    if pose_off > len(payload):
        raise SystemExit(f"{path}: pose offset past end")
    return {
        "name": name,
        "bank": len(payload),
        "code": code_n,
        "pose": len(payload) - pose_off,
        "reloc": rel_n,
        "map": map_n,
        "max": ENEMY_BANK_MAX,
    }


def collect_banks() -> list[dict]:
    banks = []
    for name in DOS_NAMES:
        path = ENEMY_DIR / f"{name}.prg"
        if not path.is_file():
            raise SystemExit(f"missing: {path}")
        banks.append(read_bank(path, name))
    crush = ENEMY_DIR / "crush.prg"
    if crush.is_file() and crush.stat().st_size > 2:
        banks.append(read_bank(crush, "crush"))
    return banks


def slim_level(lv: dict) -> dict:
    return {
        "map_bytes": lv["map_bytes"],
        "worst_room": lv["worst_room"],
        "where": lv["where"],
        "worst_types": lv["worst_types"],
        "room_assets": lv["room_assets"],
        "need": lv["need"],
        "slack": lv["slack"],
    }


def collect_variant(labels: str, *, symbols: bool = False) -> dict:
    mods = module_report(labels, symbols=symbols)
    heap, failed = heap_report(labels)
    if failed:
        raise SystemExit(f"{labels}: heap check failed")
    game = heap["game"]
    return {
        "game": {
            "load": mods["load"],
            "end": mods["end"],
            "bytes": mods["bytes"],
            "heap": game["heap_available"],
        },
        "modules": mods["modules"],
        "levels": {key: slim_level(lv) for key, lv in heap["levels"].items()},
    }


def write_report(report: dict) -> None:
    OUT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUT}")


def load_previous() -> dict:
    if not OUT.is_file():
        return {}
    try:
        data = json.loads(OUT.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def stamp_failure(step: str) -> None:
    report = load_previous()
    report["ok"] = False
    report["step"] = step
    report["time"] = now()
    report.setdefault("variants", {})
    report.setdefault("banks", [])
    report.setdefault("disks", {})
    write_report(report)


def collect_success() -> dict:
    return {
        "ok": True,
        "step": None,
        "time": now(),
        "variants": {"a8": collect_variant("game.lbl", symbols=True)},
        "banks": collect_banks(),
        "disks": {"quakea8.atr": atr_listing(ATR_PATH)},
    }


def main() -> None:
    ap = argparse.ArgumentParser(description="Write build-report.json")
    ap.add_argument(
        "--failed",
        metavar="STEP",
        help="stamp a failed build step and keep the previous report sections",
    )
    args = ap.parse_args()
    if args.failed is not None:
        stamp_failure(args.failed)
        return
    try:
        write_report(collect_success())
    except SystemExit:
        raise
    except Exception as exc:
        print(f"buildreport: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
