from dataclasses import dataclass
from pathlib import Path
import argparse
import time
import cv2
from datetime import datetime
import re
import urllib.request
import numpy as np


@dataclass
class Resolution:
    width: int
    height: int


def add_timestamp(frame):
    # Get current local time in military format (HH:MM)
    now = datetime.now()
    time_str = now.strftime("%H:%M")

    # Set font properties (medium-small, white)
    font = cv2.FONT_HERSHEY_SIMPLEX
    font_scale = 2.0
    font_thickness = 2
    color = (255, 255, 255)  # White

    # Get text size
    text_size = cv2.getTextSize(time_str, font, font_scale, font_thickness)[0]

    # Position: top-left with padding
    text_x = 20
    text_y = text_size[1] + 20

    # Put text on frame
    cv2.putText(
        frame, time_str, (text_x, text_y), font, font_scale, color, font_thickness
    )

    return frame


def fetch_snapshot_from_phone(
    phone_ip: str, port: int = 8080, max_retries: int = 3
) -> np.ndarray | None:
    """Fetch a single JPEG snapshot from IP Webcam app with retry logic."""
    url = f"http://{phone_ip}:{port}/shot.jpg"

    for attempt in range(max_retries):
        try:
            with urllib.request.urlopen(url, timeout=10) as response:
                img_array = np.asarray(bytearray(response.read()), dtype=np.uint8)
                frame = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
                return frame
        except Exception as e:
            if attempt < max_retries - 1:
                wait_time = 2**attempt  # exponential backoff: 1s, 2s, 4s
                print(f"Retry {attempt + 1}/{max_retries} after {wait_time}s - {e}")
                time.sleep(wait_time)
            else:
                print(
                    f"Failed to fetch snapshot from {url} after {max_retries} attempts: {e}"
                )
                return None


def find_last_frame_number(output_dir: Path) -> int:
    """Find the highest frame number in the output directory."""
    frame_files = list(output_dir.glob("frame_*.jpg"))
    if not frame_files:
        return 0

    max_frame = 0
    for frame_file in frame_files:
        # Extract frame number from filename (e.g., frame_0001.jpg -> 1)
        match = re.search(r"frame_(\d+)\.jpg", frame_file.name)
        if match:
            frame_num = int(match.group(1))
            max_frame = max(max_frame, frame_num)

    return max_frame


def capture_timelapse(
    duration: float,
    interval: int,
    output_dir: Path,
    use_timestamp: bool = True,
    resolution: Resolution | None = None,
    resume: bool = False,
    camera_index: int | None = None,
    phone_ip: str | None = None,
    phone_port: int = 8080,
):
    # Determine capture mode: phone snapshot (HTTP) or camera (OpenCV)
    use_phone_snapshot = phone_ip is not None
    camera = None

    if use_phone_snapshot:
        # Test phone connection with a single snapshot
        print(f"Using IP Webcam snapshot mode: http://{phone_ip}:{phone_port}/shot.jpg")
        test_frame = fetch_snapshot_from_phone(phone_ip, phone_port)
        if test_frame is None:
            raise RuntimeError(
                f"Cannot connect to IP Webcam at {phone_ip}:{phone_port}. "
                "Make sure the app is running and the IP is correct."
            )
        height, width = test_frame.shape[:2]
        print(f"Phone snapshot resolution: {width}x{height}")
        print(
            "Snapshot mode: network/battery efficient - only fetches frames when needed"
        )
    else:
        # Try different camera indices
        # If camera_index is specified, try that first
        if camera_index is not None:
            test_camera = cv2.VideoCapture(camera_index)
            if test_camera.isOpened():
                ret, frame = test_camera.read()
                if ret and frame is not None:
                    camera = test_camera
                    print(f"Using specified camera at index {camera_index}")
                else:
                    test_camera.release()
                    print(
                        f"Specified camera index {camera_index} not working, scanning..."
                    )
            else:
                test_camera.release()
                print(f"Cannot open camera at index {camera_index}, scanning...")

        # If no camera yet, try to find virtual webcam at index 20 (IP Webcam device)
        if camera is None:
            test_camera = cv2.VideoCapture(20)
            if test_camera.isOpened():
                ret, frame = test_camera.read()
                if ret and frame is not None:
                    camera = test_camera
                    print(f"Found IP Webcam virtual device at index 20")
                else:
                    test_camera.release()
            else:
                test_camera.release()

        # If still no camera, scan indices 0-10
        if camera is None:
            for i in range(10):
                test_camera = cv2.VideoCapture(i)
                if test_camera.isOpened():
                    # Test if we can actually read from it
                    ret, frame = test_camera.read()
                    if ret and frame is not None:
                        camera = test_camera
                        print(f"Found working camera at index {i}")
                        break
                    else:
                        test_camera.release()
                else:
                    test_camera.release()

        if camera is None:
            raise RuntimeError(
                "No working camera found. Please connect a camera device or use a test mode."
            )

        # Set resolution if specified
        if resolution:
            camera.set(cv2.CAP_PROP_FRAME_WIDTH, resolution.width)
            camera.set(cv2.CAP_PROP_FRAME_HEIGHT, resolution.height)

        # Get actual resolution
        width = int(camera.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(camera.get(cv2.CAP_PROP_FRAME_HEIGHT))
        print(f"Camera resolution: {width}x{height}")

    num_frames = int(duration // interval)

    # Determine starting frame number
    start_frame = 1
    if resume:
        last_frame = find_last_frame_number(output_dir)
        if last_frame > 0:
            start_frame = last_frame + 1
            print(
                f"Resuming from frame {start_frame} (found {last_frame} existing frames)"
            )
        else:
            print(
                "Resume requested but no existing frames found. Starting from frame 1."
            )

    consecutive_failures = 0
    max_consecutive_failures = 5

    try:
        for i in range(start_frame, start_frame + num_frames):
            # Capture frame based on mode
            if use_phone_snapshot:
                frame = fetch_snapshot_from_phone(phone_ip, phone_port)
                if frame is None:
                    consecutive_failures += 1
                    print(
                        f"Failed to capture frame {i} ({consecutive_failures}/{max_consecutive_failures} consecutive failures)"
                    )
                    if consecutive_failures >= max_consecutive_failures:
                        print(
                            "\nToo many consecutive failures. Phone may be asleep or disconnected."
                        )
                        print("Tips:")
                        print("  - Check if IP Webcam app is still running")
                        print("  - Disable phone sleep / keep screen on")
                        print("  - Disable battery optimization for IP Webcam")
                        print("  - Keep WiFi always on in phone settings")
                        print("\nUse --resume to continue later.")
                        break
                    continue
                consecutive_failures = 0  # reset on success
            else:
                assert camera is not None  # camera mode always has camera initialized
                ret, frame = camera.read()
                if not ret:
                    print(f"Failed to capture frame {i}")
                    continue

            # Add current timestamp to the frame if flag is True
            if use_timestamp:
                frame = add_timestamp(frame)

            filename = output_dir / f"frame_{i:04d}.jpg"
            cv2.imwrite(str(filename), frame)
            total_frames = start_frame + num_frames - 1
            print(
                f"Captured frame {i}/{total_frames}{' with timestamp' if use_timestamp else ''}"
            )

            if i < start_frame + num_frames - 1:
                time.sleep(interval)

    except KeyboardInterrupt:
        print("\nCapture interrupted by user")
    finally:
        # Release the camera if using camera mode
        if camera is not None:
            camera.release()
        print("Timelapse capture completed.")


def main():
    parser = argparse.ArgumentParser(
        description="Capture timelapse images using OpenCV."
    )
    parser.add_argument(
        "--hours",
        "-H",
        type=float,
        required=True,
        help="Duration of timelapse in hours",
    )
    parser.add_argument(
        "--interval",
        "-i",
        type=int,
        required=True,
        help="Interval between frames in seconds",
    )
    parser.add_argument(
        "--output-dir",
        "-o",
        default="timelapse_images",
        help="Where to save the frames",
    )
    parser.add_argument(
        "--add-timestamp",
        action="store_true",
        default=True,
        help="Add military time timestamp to frames (default: True)",
    )
    parser.add_argument(
        "--no-timestamp",
        action="store_true",
        help="Disable timestamp overlay (timestamps are on by default)",
    )
    parser.add_argument("--width", type=int, help="Custom width for capture")
    parser.add_argument("--height", type=int, help="Custom height for capture")
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Resume from the last captured frame instead of starting fresh",
    )
    parser.add_argument(
        "--camera-index",
        "-c",
        type=int,
        default=None,
        help="Specific camera index to use (default: auto-detect, prioritizing /dev/video20)",
    )
    parser.add_argument(
        "--phone-ip",
        "-p",
        type=str,
        default=None,
        help="IP address of phone running IP Webcam app (e.g., 192.168.1.100). "
        "Uses efficient snapshot mode - only fetches frames when needed, "
        "saving network bandwidth and phone battery.",
    )
    parser.add_argument(
        "--phone-port",
        type=int,
        default=8080,
        help="Port of IP Webcam server (default: 8080)",
    )

    args = parser.parse_args()

    duration = 3600 * args.hours  # Total duration in seconds

    resolution = None
    if args.width and args.height:
        resolution = Resolution(args.width, args.height)

    output_dir = Path(args.output_dir)
    output_dir.mkdir(exist_ok=True)

    # Determine timestamp setting: on by default, unless --no-timestamp is specified
    use_timestamp = args.add_timestamp and not args.no_timestamp

    capture_timelapse(
        duration=duration,
        interval=args.interval,
        output_dir=output_dir,
        use_timestamp=use_timestamp,
        resolution=resolution,
        resume=args.resume,
        camera_index=args.camera_index,
        phone_ip=args.phone_ip,
        phone_port=args.phone_port,
    )


if __name__ == "__main__":
    main()
