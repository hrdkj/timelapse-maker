#!/usr/bin/env python3
"""Remove camera jitter between timelapse frames.

The phone/stand is rarely perfectly rigid, so every snapshot lands at a
slightly different position/angle (measured 1-2px between neighbors, with
slow drift over hours). This script estimates each frame's camera pose
relative to its predecessor, accumulates an absolute trajectory, smooths
it (preserving slow drift, removing high-frequency jitter), and warps each
frame onto the smoothed trajectory.

Usage:
    stabilize_frames.py timelapse_imgs stabilized [--window 61]

Corrected JPEGs are written to the output directory with the same
filenames; the originals are left untouched.
"""

import argparse
from pathlib import Path

import cv2
import numpy as np

MATCH_WIDTH = 960


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


def compose(first: np.ndarray, second: np.ndarray) -> np.ndarray:
    """Affine M = first @ second (second is applied first)."""
    first3 = np.vstack([first, [0, 0, 1]])
    second3 = np.vstack([second, [0, 0, 1]])
    return (first3 @ second3)[:2]


def estimate_pair_affine(gray_a: np.ndarray, gray_b: np.ndarray) -> np.ndarray | None:
    """Estimate the affine (rotation + uniform scale + translation) mapping
    gray_a onto gray_b, via ORB features + RANSAC."""
    orb = cv2.ORB_create(2000)
    key_a, desc_a = orb.detectAndCompute(gray_a, None)
    key_b, desc_b = orb.detectAndCompute(gray_b, None)
    if desc_a is None or desc_b is None or len(desc_a) < 10 or len(desc_b) < 10:
        return None

    matcher = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)
    matches = sorted(matcher.match(desc_a, desc_b), key=lambda m: m.distance)[:300]
    if len(matches) < 8:
        return None

    src = np.float32([key_a[m.queryIdx].pt for m in matches])
    dst = np.float32([key_b[m.trainIdx].pt for m in matches])
    matrix, inliers = cv2.estimateAffinePartial2D(
        src, dst, method=cv2.RANSAC, ransacReprojThreshold=3
    )
    if matrix is None or inliers is None or inliers.sum() < 8:
        return None
    return matrix


def stabilize_frames(
    input_dir: Path,
    output_dir: Path,
    window: int = 61,
    quality: int = 95,
) -> None:
    frames = sorted(input_dir.glob("frame_*.jpg"))
    if not frames:
        raise SystemExit(f"No frame_*.jpg files found in {input_dir}")
    if len(frames) < 3:
        raise SystemExit("Need at least 3 frames to stabilize")

    output_dir.mkdir(parents=True, exist_ok=True)

    probe = cv2.imread(str(frames[0]), cv2.IMREAD_GRAYSCALE)
    height, width = probe.shape[:2]
    match_height = int(MATCH_WIDTH * height / width)

    print(f"Estimating camera trajectory for {len(frames)} frames...")
    identity = np.float32([[1, 0, 0], [0, 1, 0]])
    abs_poses = [identity]
    failed = 0
    for index in range(1, len(frames)):
        prev = cv2.imread(str(frames[index - 1]), cv2.IMREAD_GRAYSCALE)
        curr = cv2.imread(str(frames[index]), cv2.IMREAD_GRAYSCALE)
        prev_small = cv2.resize(prev, (MATCH_WIDTH, match_height))
        curr_small = cv2.resize(curr, (MATCH_WIDTH, match_height))
        pair = estimate_pair_affine(prev_small, curr_small)
        if pair is None:
            failed += 1
            pair = identity
        abs_poses.append(compose(pair, abs_poses[-1]))
        if index % 50 == 0:
            print(f"  {index}/{len(frames) - 1} pairs")
    if failed:
        print(f"Warning: {failed} pairs failed to match (treated as no motion)")

    abs_poses = np.stack(abs_poses)
    if window >= 2 and len(abs_poses) > window:
        smoothed = np.stack(
            [moving_average(abs_poses[:, r, c], window) for r in range(2) for c in range(3)]
        )
        smoothed = smoothed.reshape(2, 3, len(frames)).transpose(2, 0, 1)
    else:
        smoothed = abs_poses

    pair_delta = np.sqrt(np.sum(np.diff(abs_poses[:, :2, 2], axis=0) ** 2, axis=1))
    smooth_delta = np.sqrt(np.sum(np.diff(smoothed[:, :2, 2], axis=0) ** 2, axis=1))
    print(f"Neighbor frame movement (before): {pair_delta.mean():.2f}px")
    print(f"Neighbor frame movement (after):  {smooth_delta.mean():.2f}px")

    scale = width / MATCH_WIDTH
    for index, frame in enumerate(frames):
        raw = abs_poses[index].copy()
        raw[0, 2] *= scale
        raw[1, 2] *= scale
        target = smoothed[index].copy()
        target[0, 2] *= scale
        target[1, 2] *= scale
        warp = compose(cv2.invertAffineTransform(target), raw)
        image = cv2.imread(str(frame), cv2.IMREAD_COLOR)
        corrected = cv2.warpAffine(
            image, warp, (width, height), flags=cv2.INTER_LINEAR,
            borderMode=cv2.BORDER_REPLICATE,
        )
        cv2.imwrite(str(output_dir / frame.name), corrected, [cv2.IMWRITE_JPEG_QUALITY, quality])
        if (index + 1) % 50 == 0 or index + 1 == len(frames):
            print(f"  {index + 1}/{len(frames)} frames")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Remove camera jitter between timelapse frames."
    )
    parser.add_argument("input_dir", type=Path, help="Directory with frame_*.jpg files")
    parser.add_argument("output_dir", type=Path, help="Directory for corrected frames")
    parser.add_argument(
        "--window",
        type=int,
        default=61,
        help="Trajectory smoothing window in frames. Larger = smoother but "
        "flattens real slow camera movement (e.g. wind sway).",
    )
    parser.add_argument(
        "--quality", type=int, default=95, help="JPEG quality for corrected frames."
    )
    args = parser.parse_args()

    stabilize_frames(
        input_dir=args.input_dir,
        output_dir=args.output_dir,
        window=args.window,
        quality=args.quality,
    )


if __name__ == "__main__":
    main()
