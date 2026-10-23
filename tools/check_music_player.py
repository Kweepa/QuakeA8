#!/usr/bin/env python3
"""Run src/a8music.asm in py65 and compare its POKEY writes frame by frame with
the Python replica in genpokey.py (intro, loop, then the loop again via END).

Usage: python tools/check_music_player.py   (ACME from %ACME% or C:\\app\\acme)
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import genpokey as g  # noqa: E402

ROOT = g.ROOT
TMP = ROOT / "tmp"

WRAP = """\
!cpu 6502
!to "../tmp/music_test.bin", plain
effects_vol = $08fd
*= $5000
!source "a8music.asm"
"""


def main() -> None:
    TMP.mkdir(exist_ok=True)
    wrap = TMP / "music_test.asm"
    wrap.write_text(WRAP, encoding="ascii")
    acme = os.environ.get("ACME", r"C:\app\acme\acme.exe")
    lbl = TMP / "music_test.lbl"
    r = subprocess.run([acme, "--vicelabels", str(lbl), str(wrap)], cwd=ROOT / "src",
                       capture_output=True, text=True)
    if r.returncode:
        sys.exit(r.stdout + r.stderr)
    labels = {}
    for line in lbl.read_text().splitlines():
        m = re.match(r"al C:([0-9a-fA-F]+) \.(\S+)", line)
        if m:
            labels[m.group(2)] = int(m.group(1), 16)
    code = (TMP / "music_test.bin").read_bytes()

    # Reference: the blob as genpokey would emit it.
    # Header + tokens straight from the assembled image.
    start = labels["mus_audctl"] - 0x5000
    end = labels["mus_data_end"] - 0x5000
    ninst = (labels["mus_tokens"] - labels["mus_inst"]) // 2
    full = bytes((code[start], ninst)) + code[labels["mus_inst"] - 0x5000:end]
    tick_hz = g.emulate(g.TUNE)[0]

    from py65.devices.mpu6502 import MPU

    class WMem(bytearray):
        def __init__(self, *a):
            super().__init__(*a)
            self.pokey = bytearray(9)

        def __setitem__(self, k, v):
            if isinstance(k, int) and 0xD200 <= k <= 0xD208:
                self.pokey[k - 0xD200] = v
            elif isinstance(k, int) and 0x8000 <= k < 0xD000:
                sys.exit(f"stray write ${k:04x} (ring ran past $7FFF)")
            bytearray.__setitem__(self, k, v)

    mem = WMem(65536)
    mem[0x5000:0x5000 + len(code)] = code
    mem[0x08FD] = 0x0F
    mem[0xD014] = 0x01  # PAL: no frame skipping
    m = MPU(memory=mem)

    def call(name: str, limit: int = 100000) -> int:
        mem[0x1FF] = 0xFE
        mem[0x1FE] = 0xFF
        m.sp = 0xFD
        m.pc = labels[name]
        mem[0xFEFF] = 0xEA
        n = 0
        c0 = m.processorCycles
        while m.pc != 0xFF00:
            m.step()
            n += 1
            if n > limit:
                sys.exit(f"{name} hang")
        return m.processorCycles - c0

    ok = True
    for std, name in ((0, "PAL"), (1, "NTSC")):
        mem[0xD014] = 0x0F if std else 0x01
        audctl, _, ref = g.play_blob(full, tick_hz, std)
        call("a8_music_start")
        if mem.pokey[8] != audctl:
            sys.exit(f"AUDCTL ${mem.pokey[8]:02x} != ${audctl:02x}")
        worst = 0
        tot = 0
        bad = 0
        for k, want in enumerate(ref):
            cyc = call("a8_music_tick")
            worst = max(worst, cyc)
            tot += cyc
            p = mem.pokey
            got = (p[0], p[2], p[4], p[6], p[3], p[5], p[7])
            exp = (want[0], want[1], want[2], want[3], want[5], want[6], want[7])
            if got != exp:
                bad += 1
                if bad < 6:
                    print(f"{name} VBI {k}: got {[hex(x) for x in got]} want {[hex(x) for x in exp]}")
        print(f"check_music_player: {name} {len(ref)} VBIs (intro, loop, loop again), {bad} mismatches, "
              f"6502 cycles/VBI mean {tot / len(ref):.0f} worst {worst}")
        ok = ok and not bad
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
