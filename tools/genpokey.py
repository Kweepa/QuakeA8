#!/usr/bin/env python3
"""Menu music for the Atari port: one SidTracker64 tune -> POKEY event stream.

The PSID player is run in py65 and every $D400-$D418 write is logged. A SID
envelope model turns that into per-voice pitch / gate / wave state per SID tick.
The three SID voices are mapped onto POKEY (ch1+2 joined 16-bit @1.79 MHz,
ch3 and ch4 8-bit), and the result is packed into src/menu_music_data.asm.

The data is a sparse column stream, not volumes: the player (src/a8music.asm)
runs a small per-channel envelope every VBI from (AD, SR) pairs, and steps the
stream at the tune's tick rate with a phase accumulator (PAL and NTSC alike).

Columns (one tick = mask byte + the changed columns, absolute values):
    0 AUDF1 (pair lo)  1 AUDF2 (pair hi)  2 AUDF3  3 AUDF4
    4 E_pair           5 E_ch3            6 E_ch4
E = retrig<<7 | gate<<6 | class<<4 | inst
    class 0 pure tone ($A0)  1 poly4 tone ($C0)  2 noise ($80)  3 silent
    inst = index into the (AD, SR) table
retrig (rising gate edge since the last frame) is not part of the stored state.

The mask/value bytes go through an LZ ring (RING_BYTES at RING_BASE). Tokens
come in groups of 8 behind a flag byte (LSB first, 1 = literal byte). A match
is two bytes (three when long):
    b0 = distance, low 8 bits (1..4095)
    b1 = distance >> 8 << 4 | lencode               lencode 1..14: len = lencode+2
                                                    lencode 15: third byte n, len = n+17
lencode 0 is a control token: b0 = 0 LOOPMARK (ring write position resets; the
loop pointer is the next token), b0 = 1 END (same reset, jump to the loop
pointer). Column and envelope state carry across; the body's first frame
writes all seven columns. LOOPMARK closes its flag group.
The loop body only references bytes written since LOOPMARK.

Blob: AUDCTL, ninst, (AD, SR) * ninst, tokens.
"""

from __future__ import annotations

import argparse
import hashlib
import math
import struct
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

TUNE = ROOT / "mkmusic" / "MK_DOOM_4_REFERENCE_ringfix.sid"  # Realms of Chthon
OUT_ASM = ROOT / "src" / "menu_music_data.asm"
BUDGET = 2700  # bytes of packed data (menu.prg has to fit the ATR's free sectors)

LOAD = INIT = 0x9000
PLAY = 0x9003
PAL_PHI2 = 985248.0
POKEY_64K = 63921.0
POKEY_15K = 15699.0
POKEY_179 = 1789773.0
VBI_HZ = (1773447.0 / 35568.0, 1789773.0 / 29868.0)   # PAL 49.86, NTSC 59.92

RING_BYTES = 4096
MAX_LEN = 255
MIN_LEN = 3

RATE_PERIOD = (9, 32, 63, 95, 149, 220, 267, 313, 392, 977, 1954, 3126,
               3907, 11720, 19532, 31251)
# Envelope steps per VBI, 8.8, saturated: 16 PAL entries then 16 NTSC. The
# player has the same table (mus_spfb picks the half).
SPF = tuple(min(65535, int(round(256.0 * PAL_PHI2 / vbi / p)))
            for vbi in VBI_HZ for p in RATE_PERIOD)

# Knobs.
PITCH_STEP_CENTS = 25     # grid for pitched notes; fewer distinct values pack better
MIN_TONE_HZ = 28.0        # subsonic "tones" (kick sweeps parked at 6 Hz) play silent
AUDIBLE_LEVEL = 8         # below this (and not retriggered) pitch / class hold


def die(msg: str) -> None:
    print(f"genpokey: {msg}", file=sys.stderr)
    sys.exit(1)


# --------------------------------------------------------------------------
# SID player emulation
# --------------------------------------------------------------------------

def load_psid(path: Path) -> bytearray:
    d = path.read_bytes()
    if d[:4] != b"PSID":
        die(f"{path.name}: not a PSID")
    _ver, off, load, init, play = struct.unpack(">HHHHH", d[4:14])
    body = bytearray(d[off:])
    if load == 0:
        load = body[0] | body[1] << 8
        del body[:2]
    if (load, init, play) != (LOAD, INIT, PLAY):
        die(f"{path.name}: unexpected load/init/play")
    mem = bytearray(65536)
    mem[load:load + len(body)] = body
    return mem


def emulate(path: Path, extra_loops: int = 3):
    """Returns (tick_hz, init_writes, ticks, loop_start, loop_len).

    ticks[n] = (reg, value) writes during play call n. Ticks 0..loop_start are
    the intro; the body then repeats with period loop_len. The intro plus
    `extra_loops` bodies are emulated.
    """
    from py65.devices.mpu6502 import MPU

    mem = load_psid(path)
    cur: list[tuple[int, int]] = []

    class WMem(bytearray):
        def __setitem__(self, k, v):
            if isinstance(k, int) and (0xD400 <= k <= 0xD418 or k in (0xDC04, 0xDC05)):
                cur.append((k, v))
            bytearray.__setitem__(self, k, v)

    wm = WMem(mem)
    m = MPU(memory=wm)

    def call(addr: int) -> None:
        wm[0x1FF] = 0xFE
        wm[0x1FE] = 0xFF
        m.sp = 0xFD
        m.pc = addr
        wm[0xFEFF] = 0xEA
        n = 0
        while m.pc != 0xFF00:
            m.step()
            n += 1
            if n > 200000:
                die("player hang")

    call(INIT)
    latch = wm[0xDC04] | wm[0xDC05] << 8
    tick_hz = PAL_PHI2 / latch
    init_writes = [(k, v) for k, v in cur if k < 0xDC00]
    cur.clear()

    ticks: list[list[tuple[int, int]]] = []
    seen: dict[str, int] = {}
    loop_start = loop_len = None
    limit = 20000
    n = 0
    while n < limit:
        call(PLAY)
        ticks.append([(k, v) for k, v in cur])
        cur.clear()
        h = hashlib.md5(bytes(wm[0x9000:0xA000]) + bytes(wm[0xF0:0xF8])).hexdigest()
        if loop_start is None and h in seen:
            loop_start = seen[h]
            loop_len = n - loop_start
            limit = n + extra_loops * loop_len + 1
        seen.setdefault(h, n)
        n += 1
    if loop_start is None:
        die("no loop found")
    return tick_hz, init_writes, ticks, loop_start, loop_len


# --------------------------------------------------------------------------
# SID envelope / voice model (reference, event driven)
# --------------------------------------------------------------------------

def exp_period(level: int) -> int:
    if level >= 0x5E:
        return 1
    if level >= 0x37:
        return 2
    if level >= 0x1B:
        return 4
    if level >= 0x0F:
        return 8
    if level >= 0x07:
        return 16
    return 30


class Voice:
    def __init__(self) -> None:
        self.level = 0
        self.state = "release"
        self.gate = 0
        self.next = None  # absolute time (s) of the next envelope step
        self.ctrl = 0
        self.fn = 0
        self.ad = 0
        self.sr = 0
        self.retrig = 0   # rising gate edges since the last frame sample

    def period(self) -> float:
        if self.state == "attack":
            r = RATE_PERIOD[self.ad >> 4]
        elif self.state == "decay":
            r = RATE_PERIOD[self.ad & 15] * exp_period(self.level)
        elif self.state == "release":
            r = RATE_PERIOD[self.sr & 15] * exp_period(self.level)
        else:
            return 0.0
        return r / PAL_PHI2

    def sustain(self) -> int:
        return (self.sr >> 4) * 17

    def arm(self, t: float) -> None:
        if self.state == "release" and self.level == 0:
            self.next = None
        elif self.state == "decay" and self.level <= self.sustain():
            self.state = "sustain"
            self.next = None
        elif self.state == "sustain":
            self.next = None
        else:
            self.next = t + self.period()

    def advance(self, t: float) -> None:
        while self.next is not None and self.next <= t:
            at = self.next
            if self.state == "attack":
                self.level += 1
                if self.level >= 255:
                    self.level = 255
                    self.state = "decay"
            elif self.state in ("decay", "release"):
                self.level -= 1
            self.arm(at)

    def write_ctrl(self, v: int, t: float) -> None:
        self.advance(t)
        g = v & 1
        if g and not self.gate:
            self.state = "attack"
            self.retrig = 1
            self.arm(t)
        elif not g and self.gate:
            self.state = "release"
            self.arm(t)
        self.gate = g
        self.ctrl = v

    def write_rate(self, t: float) -> None:
        # The SID rate counter free-runs; rewriting AD/SR (instrument tables do it
        # every tick) must not restart a pending step.
        self.advance(t)
        if self.next is None:
            self.arm(t)


def wave_class(ctrl: int):
    w = ctrl & 0xF0
    if ctrl & 0x08 or w == 0:
        return None
    if w & 0x80:
        return "noise"       # noise (alone or combined) is closest to noise
    if w & 0x40:
        return "pulse"
    if w & 0x20:
        return "saw"
    return "tri"


def render_voices(tick_hz, init_writes, ticks, nticks, times):
    """Voice state at each sample time (s): list of 3-tuples per sample
    (wave | None, hz, level 0..255 incl. master, gate, retrig, AD, SR).
    retrig = rising gate edges since the previous sample."""
    voices = [Voice() for _ in range(3)]
    master = 15
    tick_s = 1.0 / tick_hz

    def apply(reg, val, t):
        nonlocal master
        if reg == 0xD418:
            master = val & 15
            return
        if reg >= 0xD415:
            return
        v, r = divmod(reg - 0xD400, 7)
        vo = voices[v]
        if r == 0:
            vo.fn = (vo.fn & 0xFF00) | val
        elif r == 1:
            vo.fn = (vo.fn & 0x00FF) | val << 8
        elif r == 4:
            vo.write_ctrl(val, t)
        elif r == 5:
            vo.advance(t)
            vo.ad = val
            vo.write_rate(t)
        elif r == 6:
            vo.advance(t)
            vo.sr = val
            vo.write_rate(t)

    for reg, val in init_writes:
        apply(reg, val, 0.0)

    frames = []
    ti = 0
    for tf in times:
        while ti < nticks and ti * tick_s <= tf + 1e-9:
            for reg, val in ticks[ti]:
                apply(reg, val, ti * tick_s)
            ti += 1
        row = []
        for vo in voices:
            vo.advance(tf)
            hz = vo.fn * PAL_PHI2 / 16777216.0
            row.append((wave_class(vo.ctrl), hz, vo.level * master / 15.0,
                        vo.gate, vo.retrig, vo.ad, vo.sr))
            vo.retrig = 0
        frames.append(row)
    return frames


# --------------------------------------------------------------------------
# POKEY mapping -> columns
# --------------------------------------------------------------------------

def cents(a: float, b: float) -> float:
    return 1200.0 * math.log2(a / b)


def quant_pitch(hz: float) -> float:
    if hz <= 0:
        return 20.0
    c = round(cents(hz, 440.0) / PITCH_STEP_CENTS) * PITCH_STEP_CENTS
    return 440.0 * 2 ** (c / 1200.0)


RES = ("pair", "c3", "c4")


def tone_8bit(hz: float, clk: float):
    """Best (audf, class, err_cents) on an 8-bit channel: pure or poly4."""
    best = None
    for cls, div in ((0, 2.0), (1, 15.0)):
        n = max(1, min(256, round(clk / (div * hz))))
        err = abs(cents(clk / (div * n), hz))
        key = err + (0.0 if cls == 0 else 20.0)   # clean tone unless poly4 is clearly closer
        if best is None or key < best[0]:
            best = (key, n - 1, cls, err)
    return best[1], best[2], best[3]


def tone_pair(hz: float):
    n = max(0, min(65535, round(POKEY_179 / (2.0 * hz) - 7)))
    return n, abs(cents(POKEY_179 / (2.0 * (n + 7)), hz))


def noise_div(hz: float, res: str, clk: float) -> int:
    rate = max(hz * 16.0, 1.0)  # SID noise LFSR clock
    if res == "pair":
        return max(0, min(65535, round(POKEY_179 / rate - 7)))
    return max(0, min(255, round(clk / rate) - 1))


def build_columns(frames, order, clk, insts):
    """Per frame (F_lo, F_hi, F3, F4, E_pair, E3, E4) plus pitch error stats."""
    cols = []
    errs = [[] for _ in range(3)]
    st = {"pair": 0, "c3": 0, "c4": 0}
    for row in frames:
        f = dict(st)
        e = {"pair": 0, "c3": 0, "c4": 0}
        for vi, (wc, hz, lvl, gate, rt, ad, sr) in enumerate(row):
            res = order[vi]
            cls = 3
            if wc and wc != "noise" and hz < MIN_TONE_HZ:
                wc = None
            if wc:
                audible = lvl >= AUDIBLE_LEVEL or rt
                if wc == "noise":
                    cls = 2
                    if audible:
                        f[res] = noise_div(hz, res, clk)
                elif res == "pair":
                    cls = 0
                    if audible:
                        n, _ = tone_pair(quant_pitch(hz))
                        f[res] = n
                        if hz > 0:
                            errs[vi].append(abs(cents(POKEY_179 / (2.0 * (n + 7)), hz)))
                else:
                    cls = 0
                    if audible:
                        a, cls, _ = tone_8bit(quant_pitch(hz), clk)
                        f[res] = a
                        div = 2.0 if cls == 0 else 15.0
                        if hz > 0:
                            errs[vi].append(abs(cents(clk / (div * (a + 1)), hz)))
            e[res] = (rt << 7) | (gate << 6) | (cls << 4) | insts[(ad, sr)]
        st.update(f)
        cols.append((f["pair"] & 255, f["pair"] >> 8, f["c3"], f["c4"],
                     e["pair"], e["c3"], e["c4"]))
    return cols, errs


def sparse_encode(cols, full_first: bool = False) -> bytes:
    """full_first: the first frame writes every column (loop body: the player
    keeps its column and envelope state across the LOOPMARK / END jump)."""
    base = [0] * 7
    out = bytearray()
    for n, f in enumerate(cols):
        m = 0
        vals = bytearray()
        for i in range(7):
            v = f[i]
            chg = ((v & 0x7F) != base[i] or (v & 0x80)) if i >= 4 else v != base[i]
            chg = chg or (full_first and n == 0)
            if chg:
                m |= 1 << i
                vals.append(v)
            base[i] = (v & 0x7F) if i >= 4 else v
        out.append(m)
        out += vals
    return bytes(out)


# --------------------------------------------------------------------------
# LZ packing
# --------------------------------------------------------------------------

def match_bits(n: int) -> int:
    return 17 if n <= 16 else 25


def lz_tokens(data: bytes, window: int):
    """Optimal parse. Tokens: ('L', byte) | ('M', dist, len)."""
    import bisect
    n = len(data)
    pos = defaultdict(list)
    for i in range(n - MIN_LEN + 1):
        pos[data[i:i + MIN_LEN]].append(i)
    cand = [[] for _ in range(n)]
    for i in range(n - MIN_LEN + 1):
        lst = pos[data[i:i + MIN_LEN]]
        k = bisect.bisect_left(lst, i) - 1
        best = 0
        while k >= 0:
            j = lst[k]
            if i - j > window:
                break
            ln = MIN_LEN
            while ln < MAX_LEN and i + ln < n and data[j + ln] == data[i + ln]:
                ln += 1
            if ln > best:
                best = ln
                cand[i].append((i - j, ln))
                if ln == MAX_LEN:
                    break
            k -= 1
    INF = 1 << 60
    cost = [INF] * (n + 1)
    how: list = [None] * (n + 1)
    cost[0] = 0
    for i in range(n):
        c = cost[i] + 9
        if c < cost[i + 1]:
            cost[i + 1] = c
            how[i + 1] = ("L", i)
        for dist, ln in cand[i]:
            for ll in range(MIN_LEN, ln + 1):
                c = cost[i] + match_bits(ll)
                if c < cost[i + ll]:
                    cost[i + ll] = c
                    how[i + ll] = ("M", dist, ll, i)
    toks = []
    i = n
    while i > 0:
        h = how[i]
        if h[0] == "L":
            toks.append(("L", data[h[1]]))
            i = h[1]
        else:
            toks.append(("M", h[1], h[2]))
            i = h[3]
    toks.reverse()
    return toks


def pack_stream(intro: bytes, loop: bytes, window: int) -> bytes:
    toks = lz_tokens(intro, window) + [("C", 0)] + lz_tokens(loop, window) + [("C", 1)]
    groups = []
    cur = []
    for t in toks:
        cur.append(t)
        if len(cur) == 8 or t == ("C", 0):
            groups.append(cur)
            cur = []
    if cur:
        groups.append(cur)
    out = bytearray()
    for grp in groups:
        flag = 0
        body = bytearray()
        for b, t in enumerate(grp):
            if t[0] == "L":
                flag |= 1 << b
                body.append(t[1])
            elif t[0] == "M":
                d = t[1]
                ln = t[2]
                if ln <= 16:
                    body += bytes((d & 0xFF, (d >> 8) << 4 | (ln - 2)))
                else:
                    body += bytes((d & 0xFF, (d >> 8) << 4 | 15, ln - 17))
            else:
                body += bytes((t[1], 0))
        out.append(flag)
        out += body
    return bytes(out)


def lz_decode(blob: bytes):
    """Replica of the 6502 byte source. Yields stream bytes; control events are
    yielded as ('mark',) / ('end',) markers; stops after the second END."""
    ring = bytearray(RING_BYTES)
    mask = RING_BYTES - 1
    wp = 0
    p = 0
    flags = 0
    nbits = 0
    loop_ptr = None
    ends = 0
    while True:
        if nbits == 0:
            flags = blob[p]
            p += 1
            nbits = 8
        lit = flags & 1
        flags >>= 1
        nbits -= 1
        if lit:
            b = blob[p]
            p += 1
            ring[wp & mask] = b
            wp += 1
            yield b
            continue
        b0 = blob[p]
        b1 = blob[p + 1]
        p += 2
        code = b1 & 15
        if code == 0:
            wp = 0
            nbits = 0
            if b0 == 0:
                loop_ptr = p
                yield ("mark",)
            else:
                ends += 1
                yield ("end",)
                if ends == 2:
                    return
                p = loop_ptr
            continue
        if code == 15:
            ln = blob[p] + 17
            p += 1
        else:
            ln = code + 2
        dist = ((b1 >> 4) << 8) | b0
        for _ in range(ln):
            b = ring[(wp - dist) & mask]
            ring[wp & mask] = b
            wp += 1
            yield b


# --------------------------------------------------------------------------
# Player replica (frame domain envelope), mirrors src/a8music.asm
# --------------------------------------------------------------------------

DIST = (0xA0, 0xC0, 0x80, 0x00)


class Chan:
    def __init__(self) -> None:
        self.reset()

    def reset(self) -> None:
        self.e = 0
        self.ph = 2
        self.lvl = 0
        self.frac = 0

    def event(self, v: int) -> None:
        self.e = v & 0x7F
        if v & 0x80:
            self.ph = 0
        elif not v & 0x40:
            self.ph = 2

    def step(self, ad: int, sr: int, base: int) -> None:
        """One VBI. base = 0 (PAL) or 16 (NTSC) into SPF."""
        if self.ph == 0:
            acc = self.frac + SPF[base + (ad >> 4)]
            self.lvl += acc >> 8
            self.frac = acc & 255
            if self.lvl >= 255:
                self.lvl = 255
                self.ph = 1
        elif self.ph == 1:
            sus = (sr >> 4) * 17
            if self.lvl > sus:
                acc = self.frac + (SPF[base + (ad & 15)] >> exp_shift(self.lvl))
                self.lvl = max(sus, self.lvl - (acc >> 8))
                self.frac = acc & 255
        else:
            if self.lvl:
                acc = self.frac + (SPF[base + (sr & 15)] >> exp_shift(self.lvl))
                self.lvl = max(0, self.lvl - (acc >> 8))
                self.frac = acc & 255

    def vol(self) -> int:
        return self.lvl >> 4


def exp_shift(level: int) -> int:
    if level >= 0x5E:
        return 0
    if level >= 0x37:
        return 1
    if level >= 0x1B:
        return 2
    if level >= 0x0F:
        return 3
    if level >= 0x07:
        return 4
    return 5


def rate16(tick_hz: float, std: int) -> int:
    """Ticks per VBI as 0.16 (std 0 PAL, 1 NTSC)."""
    return int(round(tick_hz / VBI_HZ[std] * 65536.0))


def play_blob(blob: bytes, tick_hz: float, std: int):
    """Decode the blob like the player: a 16-bit phase accumulator steps the
    stream one tick per carry, envelopes step every VBI. Runs intro, the loop
    and the loop again (second END). Returns (audctl, ticks, vbis):
      ticks[i] = (AUDF1..4, E_pair, E_ch3, E_ch4) after tick i
      vbis[k]  = (AUDF1..4, AUDC1, AUDC2, AUDC3) after VBI k (AUDC1 is 0)."""
    audctl = blob[0]
    ninst = blob[1]
    inst = [(blob[2 + 2 * i], blob[3 + 2 * i]) for i in range(ninst)]
    it = lz_decode(blob[2 + 2 * ninst:])
    col = [0] * 7
    ch = [Chan() for _ in range(3)]
    ticks = []
    vbis = []
    rate = rate16(tick_hz, std)
    acc = 0x8000
    base = 16 * std
    while True:
        acc += rate
        if acc >= 0x10000:
            acc &= 0xFFFF
            try:
                m = next(it)
                while isinstance(m, tuple):     # LOOPMARK / END: state carries across
                    m = next(it)
            except StopIteration:
                break
            for i in range(7):
                if m >> i & 1:
                    v = next(it)
                    if i >= 4:
                        ch[i - 4].event(v)
                    col[i] = v & 0x7F if i >= 4 else v
            ticks.append(tuple(col))
        audc = []
        for c in ch:
            ad, sr = inst[c.e & 15]
            c.step(ad, sr, base)
            cls = (c.e >> 4) & 3
            audc.append(DIST[cls] | c.vol() if cls != 3 else 0)
        vbis.append((col[0], col[1], col[2], col[3], 0, audc[0], audc[1], audc[2]))
    return audctl, ticks, vbis


# --------------------------------------------------------------------------

def build(args) -> None:
    tick_hz, init_writes, ticks, loop_start, loop_len = emulate(args.sid)
    print(f"genpokey: {args.sid.name}: {tick_hz:.2f} Hz ticks (kept; the player's phase "
          f"accumulator follows PAL or NTSC VBI), intro {loop_start + 1} loop {loop_len} ticks")
    ni = loop_start + 1
    nl = loop_len
    total_ticks = ni + 3 * nl
    if total_ticks > len(ticks):
        die("not enough emulated ticks")
    # One column frame per tick: the SID state right after the tick's writes.
    frames = render_voices(tick_hz, init_writes, ticks, total_ticks,
                           [k / tick_hz for k in range(total_ticks)])
    intro = frames[:ni]
    body = frames[ni + nl:ni + 2 * nl]
    same = sum(1 for a, b in zip(body, frames[ni + 2 * nl:]) if a == b)
    print(f"genpokey: intro {ni} ticks, loop {nl} ticks ({(ni + nl) / tick_hz:.1f} s); "
          f"loop pass 2 vs 3 equal in {same}/{nl} ticks")

    insts: dict = {}
    for row in intro + body:
        for r in row:
            insts.setdefault((r[5], r[6]), len(insts))
    if len(insts) > 16:
        die(f"{len(insts)} envelope pairs (max 16)")

    order = tuple(args.order.split(","))
    clk = POKEY_15K if args.clock == 15 else POKEY_64K
    if sorted(order) != sorted(RES):
        die("--order wants a permutation of pair,c3,c4")
    cols, errs = build_columns(intro + body, order, clk, insts)
    print(f"genpokey: SID voices 1..3 -> {order}, ch3/4 clock {int(clk)} Hz, "
          f"pitch grid {PITCH_STEP_CENTS} cents, {len(insts)} envelope pairs")
    for vi, e in enumerate(errs):
        if e:
            e2 = sorted(e)
            print(f"  voice {vi + 1}: {len(e)} pitched frames  cents err mean "
                  f"{sum(e) / len(e):.1f} p90 {e2[len(e2) * 9 // 10]:.1f}")

    s_intro = sparse_encode(cols[:ni])
    s_loop = sparse_encode(cols[ni:], full_first=True)
    audctl = 0x50 | (1 if clk == POKEY_15K else 0)
    hdr = bytes((audctl, len(insts))) + b"".join(bytes(k) for k in insts)
    blob = hdr + pack_stream(s_intro, s_loop, args.window)
    print(f"genpokey: {len(s_intro) + len(s_loop)} stream bytes -> {len(blob)} packed "
          f"(budget {BUDGET}, window {args.window})")

    # Round trip: decoder replica vs the columns, and envelope vs the reference.
    want_n = ni + nl + nl
    for std, name in ((0, "PAL"), (1, "NTSC")):
        _, tks, vbis = play_blob(blob, tick_hz, std)
        if len(tks) != want_n:
            die(f"{name}: decoded {len(tks)} ticks, want {want_n}")
        for k in range(want_n):
            w = cols[k if k < ni + nl else k - nl]
            if tks[k] != tuple(w[:4]) + tuple(x & 0x7F for x in w[4:]):
                die(f"{name}: round trip mismatch at tick {k}: {tks[k]} vs {w}")
        # Envelope vs the SID model at each VBI (second pass covers the END wrap).
        ref_err = []
        vbi_hz = VBI_HZ[std]
        times = [(k + 0.5) / vbi_hz for k in range(len(vbis))]
        rframes = render_voices(tick_hz, init_writes, ticks, total_ticks, times)
        for k, row in enumerate(rframes):
            for vi, r in enumerate(row):
                res = RES.index(order[vi])
                sub = r[0] and r[0] != "noise" and r[1] < MIN_TONE_HZ
                want_v = int(round(r[2] / 17.0)) if r[0] and not sub else 0
                got = vbis[k][5 + res] & 15 if vbis[k][5 + res] else 0
                ref_err.append(abs(want_v - got))
        big = sum(1 for x in ref_err if x > 2)
        print(f"genpokey: {name} {len(vbis)} VBIs, envelope replica vs SID model: mean |dvol| "
              f"{sum(ref_err) / len(ref_err):.2f}, >2 steps in {100.0 * big / len(ref_err):.1f}%")
    if len(blob) > BUDGET:
        die(f"packed data {len(blob)} > budget {BUDGET}")

    ntok = 2 + 2 * len(insts)
    lines = [
        "; Generated by tools/genpokey.py. Do not edit.",
        f"; {args.sid.name}: {ni} intro + {nl} loop ticks at {tick_hz:.2f} Hz, {len(blob)} bytes.",
        "mus_rate_lo\t!byte " + ",".join(f"${rate16(tick_hz, s) & 255:02x}" for s in (0, 1)),
        "mus_rate_hi\t!byte " + ",".join(f"${rate16(tick_hz, s) >> 8:02x}" for s in (0, 1)),
        "mus_spf_lo\t!byte " + ",".join(f"${v & 255:02x}" for v in SPF),
        "mus_spf_hi\t!byte " + ",".join(f"${v >> 8:02x}" for v in SPF),
        "mus_audctl\t!byte " + f"${blob[0]:02x}",
        "mus_inst",
        "\t!byte " + ",".join(f"${b:02x}" for b in blob[2:ntok]),
        "mus_tokens",
    ]
    for i in range(ntok, len(blob), 16):
        lines.append("\t!byte " + ",".join(f"${b:02x}" for b in blob[i:min(i + 16, len(blob))]))
    lines.append("mus_data_end")
    OUT_ASM.write_text("\n".join(lines) + "\n", encoding="ascii")
    print(f"genpokey: wrote {OUT_ASM.relative_to(ROOT)}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sid", type=Path, default=TUNE)
    ap.add_argument("--order", default="pair,c3,c4", help="resource for SID voice 1,2,3")
    ap.add_argument("--clock", type=int, choices=(15, 64), default=64, help="ch3/4 base clock (kHz)")
    ap.add_argument("--window", type=int, default=RING_BYTES - 1)
    args = ap.parse_args()
    build(args)


if __name__ == "__main__":
    main()
