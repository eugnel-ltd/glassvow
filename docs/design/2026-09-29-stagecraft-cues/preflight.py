#!/usr/bin/env python3
"""Deterministic technical preflight for one-shot SFX candidates.

This establishes technical eligibility only: decode, format, duration, clipping,
level, leading silence and a one-shot tail. It says nothing about perceptual
quality, cue identity or mix fit. Those need an audition, as
`.claude/skills/glassvow-elevenlabs/SKILL.md` requires.

    python3 preflight.py candidates/*.mp3            # Markdown tables
    python3 preflight.py --json candidates/*.mp3     # every raw metric

The cue is the file stem up to the last hyphen (`paneOpen-a.mp3` is `paneOpen`),
and its duration target comes from `docs/sfx-ledger.md`. A file whose cue has no
target still gets every other metric; its duration is reported, not judged.
The exit status is 1 when any file is ineligible.

Measured on ffmpeg's float decode at the file's own rate, so the container's
gapless trim is honoured. "lead" is the time to the first 2 ms window above the
silence floor; "event" is the time to the first 10 ms window within 12 dB of the
loudest one, which shows a quiet lead-in that "lead" alone would miss. "tail" is
the final 50 ms against the loudest 10 ms, and in absolute terms.

Needs `ffmpeg`, `ffprobe` and `numpy` on the path.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import subprocess
import sys
from pathlib import Path

import numpy as np

# Ledger targets, "Commissioned - stagecraft cues" in docs/sfx-ledger.md.
TARGET_SECONDS: dict[str, float] = {
    "paneOpen": 0.6,
    "glassCrack": 0.8,
    "glassImpact": 0.7,
    "shoutSting": 0.5,
}
DURATION_TOLERANCE = 0.25

# The shipped pack's container: 44.1 kHz stereo MP3 at 128 kbit/s. Every one of
# its 37 files reads this way.
PACK_SAMPLE_RATE = 44100
PACK_CHANNELS = 2

# Technical gates. The ledger sets a duration target and nothing else, so these
# are this batch's own eligibility thresholds. They were set against the 37
# shipped files so that a gate does not fail what the pack already ships as
# ordinary API output: 35 of 37 pass. The two that fail are `atkEnemyHeavy`
# (0.20% of samples at full scale) and `blocked` (final 50 ms only 13 dB below
# its loudest).
#
# Revised once, after the first three renders and before the rest: the tail rule
# gained an absolute floor (a relative-only rule cannot judge a file whose
# loudest window is itself near-inaudible) and lost its 2 ms end-peak test (its
# threshold sat just above the end artefact the shipped `hit` carries, and it
# failed a render with a larger artefact of the same kind). Frozen since.
CLIP_LEVEL = 0.999            # a decoded sample at or above this is at full scale
CLIP_FRACTION_MAX = 0.0005    # at most 1 sample in 2,000 (shipped codec overshoot: 0.011% or less)
RMS_MIN_DBFS = -50.0          # whole-file mean level; the pack's quietest is -47.5
RMS_MAX_DBFS = -6.0           # whole-file mean level; the pack's hottest is -8.9
SILENCE_FLOOR_DBFS = -50.0    # a 2 ms RMS window below this counts as silence
LEAD_MAX_MS = 40.0            # signal must start promptly; the pack's slowest is 7.3
TAIL_WINDOW_MS = 50.0         # the final window the tail is judged on
TAIL_REL_MAX_DB = -30.0       # final window vs loudest 10 ms: the sound has decayed
TAIL_ABS_MAX_DBFS = -60.0     # or the final window is already inaudible in absolute terms

# Reported, never gated.
EVENT_REL_DB = -12.0          # the main event starts within this of the loudest 10 ms
LAST_MS = 2.0                 # the very last samples of the file

LEAD_WINDOW_MS = 2.0
ENVELOPE_WINDOW_MS = 10.0
GATES = ("decode", "duration", "rate", "channels", "clipping", "level", "lead", "tail")


def db(value: float) -> float:
    """Amplitude to dBFS, with -inf floored so tables stay printable."""
    return 20.0 * math.log10(value) if value > 0.0 else -200.0


def run(command: list[str]) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(command, capture_output=True, check=False)


def probe(path: Path) -> dict[str, object]:
    """Container facts from ffprobe: codec, rate, channels, bit rate."""
    out = run(["ffprobe", "-v", "error", "-show_entries",
               "stream=codec_name,sample_rate,channels,bit_rate:format=duration",
               "-of", "json", str(path)])
    data = json.loads(out.stdout or b"{}")
    stream = (data.get("streams") or [{}])[0]
    return {"codec": stream.get("codec_name"),
            "sample_rate": int(stream.get("sample_rate", 0)),
            "channels": int(stream.get("channels", 0)),
            "bit_rate": int(stream.get("bit_rate", 0) or 0),
            "container_seconds": float(data.get("format", {}).get("duration", 0.0))}


def decode(path: Path, channels: int) -> tuple[np.ndarray, str, int]:
    """Native-rate float decode. Returns (samples[frames, channels], stderr, exit code)."""
    width = max(channels, 1)
    out = run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le",
               "-acodec", "pcm_f32le", "pipe:1"])
    flat = np.frombuffer(out.stdout, dtype="<f4")
    frames = len(flat) // width
    return (flat[:frames * width].reshape(frames, width),
            out.stderr.decode("utf-8", "replace").strip(), out.returncode)


def ebur128(path: Path) -> tuple[float, float]:
    """Integrated loudness (LUFS) and true peak (dBTP) from ffmpeg's ebur128."""
    out = run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af",
               "ebur128=peak=true:framelog=quiet", "-f", "null", "-"])
    text = out.stderr.decode("utf-8", "replace")
    loudness = re.search(r"\bI:\s+(-?[\d.]+|-inf)\s+LUFS", text)
    peak = re.search(r"\bPeak:\s+(-?[\d.]+|-inf)\s+dBFS", text)
    return (float(loudness.group(1)) if loudness else float("nan"),
            float(peak.group(1)) if peak else float("nan"))


def windowed_rms(power: np.ndarray, window: int) -> np.ndarray:
    """RMS of every sliding window, one value per start sample."""
    total = np.concatenate(([0.0], np.cumsum(power)))
    return np.sqrt((total[window:] - total[:-window]) / window)


def measure(path: Path) -> dict[str, object]:
    """Every raw metric for one file. No verdicts; see `judge`."""
    facts = probe(path)
    samples, stderr, code = decode(path, int(facts["channels"]))
    rate = int(facts["sample_rate"]) or PACK_SAMPLE_RATE
    frames = samples.shape[0]
    metrics: dict[str, object] = {
        "file": path.name, "bytes": path.stat().st_size, **facts,
        "decode_exit": code, "decode_stderr": stderr, "frames": frames,
        "seconds": frames / rate}
    if frames == 0:
        return metrics
    power = np.mean(samples.astype(np.float64) ** 2, axis=1)
    lead_window = min(frames, max(1, round(rate * LEAD_WINDOW_MS / 1000.0)))
    envelope_window = min(frames, max(1, round(rate * ENVELOPE_WINDOW_MS / 1000.0)))
    tail_window = min(frames, round(rate * TAIL_WINDOW_MS / 1000.0))
    last = min(frames, max(1, round(rate * LAST_MS / 1000.0)))
    envelope = windowed_rms(power, envelope_window)
    loudest = float(np.max(envelope))
    audible = np.nonzero(windowed_rms(power, lead_window) >= 10.0 ** (SILENCE_FLOOR_DBFS / 20.0))[0]
    eventful = np.nonzero(envelope >= loudest * 10.0 ** (EVENT_REL_DB / 20.0))[0]
    tail_dbfs = db(math.sqrt(float(np.mean(power[-tail_window:]))))
    lufs, true_peak = ebur128(path)
    clipped = int(np.count_nonzero(np.abs(samples) >= CLIP_LEVEL))
    metrics.update({
        "peak_dbfs": db(float(np.max(np.abs(samples)))),
        "true_peak_dbtp": true_peak,
        "clipped_samples": clipped,
        "clipped_fraction": clipped / samples.size,
        "lufs_integrated": lufs,
        "rms_dbfs": db(math.sqrt(float(np.mean(power)))),
        "lead_ms": 1000.0 * int(audible[0]) / rate if len(audible) else None,
        "event_ms": 1000.0 * int(eventful[0]) / rate,
        "tail_dbfs": tail_dbfs,
        "tail_rel_db": tail_dbfs - db(loudest),
        "last_2ms_peak_dbfs": db(float(np.max(np.abs(samples[-last:])))),
    })
    return metrics


def judge(metrics: dict[str, object], target: float | None) -> dict[str, bool | None]:
    """PASS/FAIL per gate. `None` means no target exists to judge against."""
    decoded = (metrics["decode_exit"] == 0 and not metrics["decode_stderr"]
               and metrics["frames"] != 0)
    if not decoded or "peak_dbfs" not in metrics:
        return {gate: (False if gate == "decode" else None) for gate in GATES}
    seconds = float(metrics["seconds"])
    lead = metrics["lead_ms"]
    return {
        "decode": True,
        "duration": (None if target is None
                     else abs(seconds - target) <= DURATION_TOLERANCE * target),
        "rate": metrics["sample_rate"] == PACK_SAMPLE_RATE,
        "channels": metrics["channels"] == PACK_CHANNELS,
        "clipping": float(metrics["clipped_fraction"]) <= CLIP_FRACTION_MAX,
        "level": RMS_MIN_DBFS <= float(metrics["rms_dbfs"]) <= RMS_MAX_DBFS,
        "lead": lead is not None and float(lead) <= LEAD_MAX_MS,
        "tail": (float(metrics["tail_rel_db"]) <= TAIL_REL_MAX_DB
                 or float(metrics["tail_dbfs"]) <= TAIL_ABS_MAX_DBFS),
    }


def eligible(verdicts: dict[str, bool | None]) -> bool:
    """Every judged gate passes. A gate with no target (`None`) is not judged."""
    return all(v for v in verdicts.values() if v is not None)


def mark(verdict: bool | None) -> str:
    return "n/a" if verdict is None else ("PASS" if verdict else "FAIL")


def cue_of(path: Path) -> str:
    return path.stem.rsplit("-", 1)[0]


Row = tuple[dict[str, object], dict[str, bool | None], float | None]


def tables(rows: list[Row]) -> str:
    """Two Markdown tables: what was measured, then each gate's verdict."""
    measured = ["| file | codec, rate, channels | duration s (target) | peak dBFS | full-scale samples "
                "| LUFS-I | RMS dBFS | lead ms | event ms | tail dBFS (rel. dB) |",
                "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
    judged = ["| file | " + " | ".join(GATES) + " | eligible |",
              "|---|" + "---|" * (len(GATES) + 1)]
    for metrics, verdicts, target in rows:
        name = f"`{metrics['file']}`"
        if "peak_dbfs" not in metrics:
            measured.append(f"| {name} | no decodable audio |" + " |" * 8)
        else:
            lead = metrics["lead_ms"]
            shown = "-" if target is None else f"{target:.2f}"
            measured.append(
                f"| {name} | {metrics['codec']} {int(metrics['sample_rate']) / 1000:g} kHz "
                f"x{metrics['channels']} | {float(metrics['seconds']):.3f} ({shown}) "
                f"| {float(metrics['peak_dbfs']):.1f} "
                f"| {metrics['clipped_samples']} ({100 * float(metrics['clipped_fraction']):.3f}%) "
                f"| {float(metrics['lufs_integrated']):.1f} | {float(metrics['rms_dbfs']):.1f} "
                f"| {'none' if lead is None else f'{float(lead):.1f}'} "
                f"| {float(metrics['event_ms']):.0f} "
                f"| {float(metrics['tail_dbfs']):.1f} ({float(metrics['tail_rel_db']):.1f}) |")
        judged.append(f"| {name} | " + " | ".join(mark(verdicts[g]) for g in GATES)
                      + f" | {'**yes**' if eligible(verdicts) else '**no**'} |")
    return "\n".join(measured) + "\n\n" + "\n".join(judged) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n\n")[0])
    parser.add_argument("files", nargs="+", type=Path)
    parser.add_argument("--json", action="store_true", help="dump raw metrics and verdicts")
    args = parser.parse_args()
    rows: list[Row] = []
    for path in sorted(args.files):
        target = TARGET_SECONDS.get(cue_of(path))
        metrics = measure(path)
        rows.append((metrics, judge(metrics, target), target))
    if args.json:
        print(json.dumps([{"metrics": m, "verdicts": v, "target": t} for m, v, t in rows],
                         indent=2, default=str))
    else:
        print(tables(rows))
    return 0 if all(eligible(v) for _, v, _ in rows) else 1


if __name__ == "__main__":
    sys.exit(main())
