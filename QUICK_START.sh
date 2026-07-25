#!/bin/bash

# Quick reference for common timelapse recording scenarios
# Run this to see usage examples

cat << 'EOF'
=== Timelapse Maker - Quick Reference ===

PHONE WEBCAM SETUP (Android via WiFi):
--------------------------------------
1. Install dependencies (one-time):
   sudo apt install -y v4l2loopback-dkms v4l2loopback-utils

2. Install "IP Webcam" app on Android phone from Play Store

3. Start phone stream:
   ./start_phone_stream.sh
   (Keep this running in one terminal)

4. Record session (in another terminal):
   ./record_session.sh --hours 8

5. Create video:
   ./create_twitter_video.sh


COMMON RECORDING SCENARIOS:
---------------------------
# Half-day work session (4 hours)
./record_session.sh --hours 4
→ 480 frames, ~20s video @ 24fps

# Full work day (8 hours)  
./record_session.sh --hours 8
→ 960 frames, ~40s video @ 24fps

# Study session with longer intervals (45s)
./record_session.sh --hours 6 --interval 45
→ 480 frames, ~20s video @ 24fps

# Quick test (5 minutes)
./record_session.sh --hours 0.083
→ 10 frames, <1s video @ 24fps

PAUSE / RESUME:
While recording, type p then Enter to pause, and r then Enter to resume.
Paused time does not count toward the session duration.


TRADITIONAL CAMERA SETUP:
--------------------------
# Use built-in webcam or USB camera
./run_timelapse.sh --hours 12 --interval 15

# With timestamp overlay
uv run capture_timelapse.py --hours 8 --interval 30 --add-timestamp


VIDEO CREATION OPTIONS:
-----------------------
# Default (auto-named, 24fps)
./create_twitter_video.sh

# Custom name
./create_twitter_video.sh --output my_session.mp4

# Different framerate
./create_twitter_video.sh --framerate 30

# From specific folder
./create_twitter_video.sh --input custom_imgs/ --output custom.mp4


TIPS:
-----
- Keep phone plugged in during recording
- Ensure strong WiFi connection
- Test with 5-min recording first
- 30s intervals work great for 6-8 hour sessions
- Position phone to show face, hands, and workspace

For detailed setup: See PHONE_WEBCAM_SETUP.md
For traditional setup: See README.md

EOF
