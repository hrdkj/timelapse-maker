# timelapse-maker

Python scripts to create camera timelapses on desktop PCs, raspberry pis, and macbooks.

## Phone as Webcam (NEW!)

You can now use your Android phone as a webcam over WiFi! Perfect for recording study/work timelapses for social media accountability.

**Quick start:**
1. See [PHONE_WEBCAM_SETUP.md](PHONE_WEBCAM_SETUP.md) for detailed setup
2. Run `./QUICK_START.sh` for quick reference commands

**Optimized for Twitter timelapses:**
- 720p resolution
- 30-second intervals
- 24fps output
- Auto-compressed for social media

---

# Requirements
- Python >= 3.11
- Git
- uv (Python package manager)
- macOS or Linux (not tested on Windows)
- OpenCV for Python (`opencv-python`)
- ffmpeg

## Setup

### Install uv
```bash
# macOS and Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# Or using Homebrew (macOS)
brew install uv

# Or using pip
pip install uv
```

### Cloning the Project
```bash
git clone https://github.com/Infatoshi/timelapse-maker
cd timelapse-maker
uv sync
```

### Linux
```bash
sudo apt install ffmpeg
# Dependencies are installed via uv sync (no need to install opencv-python separately)
```

### MacOS
```bash 
brew install ffmpeg
# Dependencies are installed via uv sync (no need to install opencv-python separately)
```

### Windows
- Open the command prompt with -> Windows key then "cmd"
- `cd` into your project folder. Ex: `cd C:\User\Desktop\python-projs\timelapse-maker`
- Install uv and run `uv sync`

## Usage

### Option 1: Complete Workflow (Recommended)
Use the shell script for automated capture and video creation:
```bash
./run_timelapse.sh [--hours <hours>] [--interval <seconds>] [--output-dir <dir>] [--width <w>] [--height <h>] [--no-timestamp]
```

Examples:
```bash
# 20-hour timelapse with 15-second intervals (defaults)
./run_timelapse.sh

# 12-hour timelapse with 30-second intervals
./run_timelapse.sh --hours 12 --interval 30

# Custom resolution without timestamp
./run_timelapse.sh --hours 8 --interval 10 --width 1920 --height 1080 --no-timestamp --resume
```

**Note**: If the output directory contains existing frames, the script will prompt you to either:
- Start fresh (removes existing images)
- Resume from the last captured frame (continues numbering sequentially)

### Option 2: Manual Steps
Run the Python scripts individually using `uv run`:

#### Capture Images
```bash
uv run capture_timelapse.py --hours 12 --interval 15 --output-dir timelapse_imgs [--width <w>] [--height <h>] [--add-timestamp] [--resume]
```

#### Create Video
```bash
uv run create_timelapse.py <image_folder> <output_video.mp4>
```

Example:
```bash
uv run capture_timelapse.py --hours 12 --interval 15 --output-dir timelapse_imgs --add-timestamp
uv run create_timelapse.py timelapse_imgs videos/my_timelapse.mp4

# Resume from last frame if capture was interrupted
uv run capture_timelapse.py --hours 12 --interval 15 --output-dir timelapse_imgs --resume
```

## Features
- **Automatic camera detection**: Scans for available cameras and uses the first working one
- **Built-in timestamps**: Add military time (HH:MM) to each frame
- **Custom resolution**: Set specific width and height for capture
- **Flexible intervals**: Configure time between captures (seconds)
- **Pause and resume controls**: While `record_session.sh` is recording, type `p` then Enter to pause and `r` then Enter to resume. Paused time does not reduce the requested recording duration.
- **Resume capability**: Continue capturing from the last frame if interrupted
- **Organized output**: Automatic directory structure for images and videos
- **Error handling**: Graceful handling of camera issues and interruptions

## License

MIT
