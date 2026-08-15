#!/usr/bin/env python3
"""Reduce frame-to-frame flicker in a timelapse image sequence.

Phone cameras run auto-exposure and auto-white-balance independently for
each snapshot, so consecutive timelapse frames can differ in brightness by
far more than the real scene change (often 10-20% frame to frame). This
script computes each frame's luminance and color balance, smooths them
over a time window (so real, slow changes like day/night transitions are
preserved), and rescales every frame to match that smoothed curve.

Usage:
    deflicker_frames.py timelapse_imgs deflickered [--window 31]

Corrected JPEGs are written to the output directory with the same
filenames; the originals are left untouched.
"""

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

LUMA_COEFFS = np.array([0.299, 0.587, 0.114], dtype=np.float32)


def moving_average(values: np.ndarray, window: int) -> np.ndarray:
    """Centered moving average with edge-clamped padding."""
    if window < 2 or len(values) <= window:
        return values.copy()
    if window % 2 == 0:
        window += 1
    half = window // 2
    kernel = np.ones(window, dtype=np.float64) / window
    padded = np.pad(values, (half, half), mode="edge")
    return np.convolve(padded, kernel, mode="same")[half:-half]


def per_channel_means(path: Path) -> np.ndarray:
    """Mean R, G, B values of a JPEG, as a float32 vector."""
    image = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    return image.reshape(-1, 3).mean(axis=0)


def deflicker_frames(
    input_dir: Path,
    output_dir: Path,
    window: int = 31,
    min_gain: float = 0.6,
    max_gain: float = 1.6,
    wb_limit: float = 0.08,
    quality: int = 95,
) -> None:
    frames = sorted(input_dir.glob("frame_*.jpg"))
    if not frames:
        raise SystemExit(f"No frame_*.jpg files found in {input_dir}")
    if len(frames) < 3:
        raise SystemExit("Need at least 3 frames to deflicker")

    output_dir.mkdir(parents=True, exist_ok=True)
    fix_white_balance = wb_limit > 0

    print(f"Analyzing {len(frames)} frames...")
    means = np.stack([per_channel_means(frame) for frame in frames])
    green = np.maximum(means[:, 1], 1.0)
    luma = means @ LUMA_COEFFS

    target_luma = moving_average(luma, window)
    luma_gain = np.clip(target_luma / np.maximum(luma, 1.0), min_gain, max_gain)

    red_gain = np.ones(len(frames), dtype=np.float64)
    blue_gain = np.ones(len(frames), dtype=np.float64)
    if fix_white_balance:
        red_ratio = means[:, 0] / green
        blue_ratio = means[:, 2] / green
        red_gain = np.clip(
            moving_average(red_ratio, window) / red_ratio,
            1 - wb_limit,
            1 + wb_limit,
        )
        blue_gain = np.clip(
            moving_average(blue_ratio, window) / blue_ratio,
            1 - wb_limit,
            1 + wb_limit,
        )

    before = float(np.abs(np.diff(luma)).mean())
    print(f"Neighbor frame brightness diff (before): {before:.2f}")

    for index, frame in enumerate(frames):
        image = np.asarray(Image.open(frame).convert("RGB"), dtype=np.float32)
        image *= luma_gain[index]
        if fix_white_balance:
            image[:, :, 0] *= red_gain[index]
            image[:, :, 2] *= blue_gain[index]
        corrected = np.clip(image, 0, 255).astype(np.uint8)
        Image.fromarray(corrected).save(output_dir / frame.name, quality=quality)
        if (index + 1) % 50 == 0 or index + 1 == len(frames):
            print(f"  {index + 1}/{len(frames)} frames")

    luma_after = np.clip(luma * luma_gain, 0, 255)
    after = float(np.abs(np.diff(luma_after)).mean())
    print(f"Neighbor frame brightness diff (after): {after:.2f}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Remove short-term brightness flicker from timelapse frames."
    )
    parser.add_argument("input_dir", type=Path, help="Directory with frame_*.jpg files")
    parser.add_argument("output_dir", type=Path, help="Directory for corrected frames")
    parser.add_argument(
        "--window",
        type=int,
        default=31,
        help="Smoothing window in frames. At a 30s capture interval, 31 frames "
        "is ~15 minutes: long enough to smooth exposure jitter, short enough "
        "to keep real changes (clouds, sunset).",
    )
    parser.add_argument(
        "--min-gain",
        type=float,
        default=0.6,
        help="Lowest allowed brightness correction factor (0.6 = 40% dimmer).",
    )
    parser.add_argument(
        "--max-gain",
        type=float,
        default=1.6,
        help="Highest allowed brightness correction factor (1.6 = 60% brighter).",
    )
    parser.add_argument(
        "--wb-limit",
        type=float,
        default=0.08,
        help="Max relative per-channel color correction for white-balance "
        "flicker, e.g. 0.08 = 8%. Set to 0 to disable color correction.",
    )
    parser.add_argument(
        "--quality", type=int, default=95, help="JPEG quality for corrected frames."
    )
    args = parser.parse_args()

    deflicker_frames(
        input_dir=args.input_dir,
        output_dir=args.output_dir,
        window=args.window,
        min_gain=args.min_gain,
        max_gain=args.max_gain,
        wb_limit=args.wb_limit,
        quality=args.quality,
    )


if __name__ == "__main__":
    main()
