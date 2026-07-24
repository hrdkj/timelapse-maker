# Phone Webcam Setup Guide for Timelapse Recording

This guide shows you how to set up your Android phone as a webcam over WiFi using IP Webcam, then use it to record study/work timelapses for Twitter.

## Quick Start Summary

1. Install system dependencies (one-time setup)
2. Install IP Webcam app on your phone
3. Start phone stream with `./start_phone_stream.sh`
4. Record your session with `./record_session.sh`
5. Create Twitter video with `./create_twitter_video.sh`

---

## Detailed Setup Instructions

### Step 1: Install System Dependencies (One-Time Setup)

Install the required kernel module for creating virtual webcam devices:

```bash
sudo pacman -S v4l2loopback-dkms
```

Verify installation:
```bash
modinfo v4l2loopback
```

You should see module information without errors.

### Step 2: Install IP Webcam on Your Android Phone

1. Open Google Play Store on your Android phone
2. Search for "IP Webcam" by Pavel Khlebovich
3. Install the app (it's free)

### Step 3: Connect Phone and Computer to Same WiFi

Make sure both your phone and computer are connected to the same WiFi network.

---

## Daily Workflow

### Step 1: Start IP Webcam on Your Phone

1. Open the IP Webcam app on your phone
2. Scroll down to the bottom
3. Tap "Start server"
4. The app will show an IP address like: `http://192.168.1.100:8080`
5. Note down the IP address (the numbers before the colon)

**Phone positioning tips:**
- Mount phone 3-4 feet away from your desk
- Angle slightly downward (15-30 degrees)
- Frame yourself, your hands, and your workspace
- Face a light source (window or lamp) - avoid backlighting
- Keep phone plugged in (streaming drains battery)

### Step 2: Start Phone Stream on Computer

Run the streaming script and enter your phone's IP when prompted:

```bash
./start_phone_stream.sh
```

When prompted, enter just the IP address (e.g., `192.168.1.100`), not the full URL.

This script will:
- Load the v4l2loopback kernel module
- Create a virtual webcam at `/dev/video20`
- Stream from your phone to the virtual device
- Run in the foreground (keep this terminal open)

**Keep this terminal window open while recording!**

### Step 3: Record Your Session (In a New Terminal)

Open a new terminal and run:

```bash
./record_session.sh --hours 8
```

This will:
- Capture frames every 30 seconds
- Record in 720p (1280x720)
- Save frames to `timelapse_imgs/` folder
- No timestamp overlay (clean video)
- Auto-detect the virtual webcam

**Options:**
```bash
# Custom duration
./record_session.sh --hours 6

# Custom interval (in seconds)
./record_session.sh --hours 8 --interval 45

# Show all options
./record_session.sh --help
```

**Expected frame counts:**
- 4 hours @ 30s intervals = 480 frames = 20s video @ 24fps
- 6 hours @ 30s intervals = 720 frames = 30s video @ 24fps
- 8 hours @ 30s intervals = 960 frames = 40s video @ 24fps

### Step 4: Create Twitter Video

After recording completes (or you stop it with Ctrl+C):

```bash
./create_twitter_video.sh
```

This will:
- Create a video at 24fps
- Optimize for Twitter (H.264, fast start)
- Save to `videos/` folder with timestamp
- Display file size and duration
- Warn if it exceeds Twitter limits

**Options:**
```bash
# Specify output name
./create_twitter_video.sh --output my_study_session.mp4

# Use different image folder
./create_twitter_video.sh --input other_folder

# Show all options
./create_twitter_video.sh --help
```

### Step 5: Upload to Twitter

The video is now ready! Upload it to Twitter with your accountability post.

**Twitter limits:**
- Max duration: 140 seconds (2:20)
- Max file size: 512MB
- Your videos will be well under these limits

---

## Troubleshooting

### "No working camera found"

**Problem:** Script can't detect the virtual webcam.

**Solution:**
1. Make sure `start_phone_stream.sh` is still running
2. Check if `/dev/video20` exists: `ls -la /dev/video20`
3. Verify the module is loaded: `lsmod | grep v4l2loopback`
4. If not loaded, run: `sudo modprobe v4l2loopback devices=1 video_nr=20 card_label="IPWebcam" exclusive_caps=1`

### "Cannot connect to IP Webcam stream"

**Problem:** Computer can't reach the phone.

**Solution:**
1. Verify phone and computer are on the same WiFi
2. Check IP address is correct (shown in IP Webcam app)
3. Make sure "Start server" is pressed in IP Webcam app
4. Try pinging the phone: `ping 192.168.1.100` (use your phone's IP)
5. Check firewall isn't blocking port 8080

### Poor video quality or lag

**Problem:** Stream is choppy or low quality.

**Solution:**
1. Use stronger WiFi signal (move closer to router)
2. In IP Webcam app settings:
   - Video resolution: 1280x720 or 1920x1080
   - Quality: 80-90
   - FPS limit: 15-30
3. Close other apps using bandwidth
4. Consider using USB tethering instead (requires different setup)

### Phone battery draining too fast

**Problem:** Phone dies before session ends.

**Solution:**
1. Keep phone plugged in while recording (strongly recommended)
2. In IP Webcam app, reduce:
   - Video quality
   - FPS (10-15 is fine for timelapses)
3. Disable other features in IP Webcam (motion detection, etc.)

### Module won't load on boot

**Problem:** Have to manually load v4l2loopback every time.

**Solution:**
Create a config file to auto-load on boot:

```bash
echo "v4l2loopback" | sudo tee /etc/modules-load.d/v4l2loopback.conf
echo 'options v4l2loopback devices=1 video_nr=20 card_label="IPWebcam"' | sudo tee /etc/modprobe.d/v4l2loopback.conf
```

Reboot and the module will load automatically.

---

## Technical Details

### What Each Script Does

**start_phone_stream.sh:**
- Loads v4l2loopback kernel module
- Creates virtual webcam device at `/dev/video20`
- Uses ffmpeg to stream from IP Webcam to virtual device
- Transcodes MJPEG from phone to YUYV422 format for OpenCV

**record_session.sh:**
- Wrapper around `capture_timelapse.py`
- Preset for study sessions: 720p, 30s intervals, no timestamp
- Auto-detects virtual webcam at index 20
- Calculates expected video duration

**create_twitter_video.sh:**
- Creates video at 24fps (smooth, cinematic)
- H.264 codec with optimized settings
- Checks Twitter limits (140s, 512MB)
- Auto-generates filename with timestamp

### Camera Detection Priority

The modified `capture_timelapse.py` now checks cameras in this order:

1. Specified `--camera-index` if provided
2. Index 20 (virtual webcam from IP Webcam)
3. Indices 0-10 (built-in cameras, USB cameras)

This ensures your phone webcam is used automatically without manual configuration.

### Storage Requirements

**Per session:**
- 4 hours @ 30s: ~480 frames × 200KB = ~96MB
- 8 hours @ 30s: ~960 frames × 200KB = ~192MB
- Final video: 10-50MB (after compression)

Very manageable on modern systems!

---

## Advanced Usage

### Manual Camera Selection

If you have multiple cameras and want to force a specific one:

```bash
uv run capture_timelapse.py --hours 8 --interval 30 --camera-index 20 --width 1280 --height 720 --output-dir timelapse_imgs
```

### Different Video Framerates

```bash
# Slower, longer video (12fps = 2x longer)
./create_twitter_video.sh --framerate 12

# Faster, shorter video (48fps = 2x shorter)
./create_twitter_video.sh --framerate 48
```

### Resume Interrupted Recording

If recording stops early, resume from the last frame:

```bash
./record_session.sh --hours 8  # Will prompt to resume if frames exist
```

Or use the original script directly:

```bash
uv run capture_timelapse.py --hours 4 --interval 30 --resume --output-dir timelapse_imgs --width 1280 --height 720
```

### Add Timestamps to Video

If you want to show the time progression:

```bash
uv run capture_timelapse.py --hours 8 --interval 30 --add-timestamp --width 1280 --height 720 --output-dir timelapse_imgs
```

---

## Testing Before First Real Session

Before recording a full work session, test everything works:

```bash
# 1. Start phone stream
./start_phone_stream.sh

# 2. In another terminal, quick 5-minute test
./record_session.sh --hours 0.083  # 5 minutes = 0.083 hours

# 3. Create test video
./create_twitter_video.sh --output test.mp4

# 4. Watch the test video
xdg-open videos/test.mp4
```

This captures 10 frames (5 min ÷ 30s) and creates a sub-1-second video. Perfect for verifying your setup!

---

## Tips for Great Timelapses

1. **Lighting:** Good lighting makes a huge difference. Face a window or lamp.
2. **Framing:** Show enough context - your face, hands, and workspace.
3. **Stability:** Mount phone securely so it doesn't shift during recording.
4. **Battery:** Always keep phone plugged in for sessions over 2 hours.
5. **Intervals:** 30s is great for 6-8 hour sessions. Use 15-20s for shorter sessions.
6. **WiFi:** Strong signal prevents dropped frames. Stay close to router.

---

## Questions or Issues?

If you run into issues not covered here:

1. Check the "Troubleshooting" section above
2. Verify all dependencies are installed
3. Test with a short capture first
4. Check that phone and computer are on same network
5. Make sure IP Webcam server is running on phone

Happy recording!
