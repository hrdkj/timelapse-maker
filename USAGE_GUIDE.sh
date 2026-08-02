#!/bin/bash

# Interactive guide for using the timelapse system
# Run this to get a step-by-step walkthrough

cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║     Study/Work Timelapse Recording - Daily Workflow Guide     ║
╔════════════════════════════════════════════════════════════════╝

════════════════════════════════════════════════════════════════
STEP 1: POSITION YOUR PHONE
════════════════════════════════════════════════════════════════

Before starting, set up your phone:

✓ Mount/prop phone 3-4 feet away from your workspace
✓ Angle slightly downward (15-30 degrees) to capture you + desk
✓ Ensure good framing: face, hands, keyboard/notebook visible
✓ Face a light source (window or lamp) - avoid backlit setup
✓ PLUG IN YOUR PHONE - streaming drains battery fast!
✓ Keep phone stable - any movement will show in the timelapse

Quick framing check:
  - Can you see your face clearly?
  - Can you see your hands/workspace?
  - Is the lighting even (not too dark/bright)?

════════════════════════════════════════════════════════════════
STEP 2: START IP WEBCAM ON YOUR PHONE
════════════════════════════════════════════════════════════════

On your Android phone:
1. Open "IP Webcam" app
2. Scroll to bottom
3. Tap "Start server"
4. Note the IP address shown (e.g., 192.168.31.158:8080)
5. You can lock your phone screen to save battery

TIP: Keep the phone plugged in!

════════════════════════════════════════════════════════════════
STEP 3: START PHONE STREAM (TERMINAL 1)
════════════════════════════════════════════════════════════════

In your first terminal window:

    ./start_phone_stream.sh

When prompted, enter your phone's IP (just the numbers):
    Example: 192.168.31.158

You'll see ffmpeg output - this is normal!
KEEP THIS TERMINAL OPEN while recording.

Signs it's working:
  ✓ See "Stream #0:0: Video: mjpeg..." 
  ✓ Frame counter increasing (frame=XXX)
  ✓ No errors about "Connection refused"

════════════════════════════════════════════════════════════════
STEP 4: START RECORDING (TERMINAL 2 - NEW WINDOW)
════════════════════════════════════════════════════════════════

Open a NEW terminal (keep the stream running in terminal 1).

For typical recording sessions:

    # 4-hour study session → ~20 second video
    ./record_session.sh --hours 4

    # 6-hour work session → ~30 second video
    ./record_session.sh --hours 6

    # 8-hour full day → ~40 second video
    ./record_session.sh --hours 8

The script will:
  - Tell you expected frame count
  - Show video duration estimate
  - Ask about existing frames (start fresh or resume)
  - Start capturing

You'll see: "Captured frame X/Y" every 30 seconds

WHAT TO DO DURING RECORDING:
  ✓ Just work/study normally!
  ✓ Don't worry about the camera
  ✓ Take breaks when needed (will show in timelapse)
  ✓ Keep phone plugged in
  ✓ Don't move the phone
  ✓ Ensure laptop doesn't sleep (disable auto-sleep)

TO STOP EARLY:
  Press Ctrl+C in the recording terminal
  Frames captured so far are saved and usable!

════════════════════════════════════════════════════════════════
STEP 5: CREATE YOUR TWITTER VIDEO
════════════════════════════════════════════════════════════════

After recording completes (or you stop it early):

    ./create_twitter_video.sh

This creates a 24fps video optimized for Twitter.

Output location: videos/session_YYYY_monDD_HHhMM.mp4

The script shows:
  - Video duration
  - File size
  - Warnings if it exceeds Twitter limits

CUSTOM OUTPUT NAME:
    ./create_twitter_video.sh --output my_grind_session.mp4

════════════════════════════════════════════════════════════════
STEP 6: REVIEW & POST TO TWITTER
════════════════════════════════════════════════════════════════

Watch your video first:

    xdg-open videos/your_video.mp4

Check:
  ✓ Framing looks good
  ✓ Lighting is acceptable
  ✓ Can see you working
  ✓ Duration is good for Twitter

Then upload to Twitter with your accountability caption!

Example captions:
  "8 hours of deep work on [project] 📚💻 #StudyWithMe"
  "Building in public - 6 hours of focused work ⚡"
  "Consistency > Motivation. Day X of 100. 🔥"

════════════════════════════════════════════════════════════════
STEP 7: CLEANUP (OPTIONAL)
════════════════════════════════════════════════════════════════

After posting, you can delete the source frames to save space:

    rm -rf timelapse_imgs/*.jpg

The video is already created, so frames aren't needed anymore.

Keep videos archived in videos/ folder for your records!

════════════════════════════════════════════════════════════════
QUICK REFERENCE - COMPLETE WORKFLOW
════════════════════════════════════════════════════════════════

Terminal 1:
    ./start_phone_stream.sh
    [Enter phone IP]
    [Keep running]

Terminal 2:
    ./record_session.sh --hours 8
    [Let it run while you work]
    [Ctrl+C when done, or let it finish]
    
    ./create_twitter_video.sh
    
    xdg-open videos/session_*.mp4
    
    [Post to Twitter!]

════════════════════════════════════════════════════════════════
TRADITIONAL CAMERA SETUP (no phone)
════════════════════════════════════════════════════════════════

Using a built-in webcam or USB camera instead of your phone:

    # 12-hour timelapse, 15s intervals
    ./run_timelapse.sh --hours 12 --interval 15

    # With custom resolution
    ./run_timelapse.sh --hours 8 --interval 10 --width 1920 --height 1080

    # Timestamp overlay
    ./run_timelapse.sh --hours 8 --interval 30 --add-timestamp

VIDEO CREATION OPTIONS:
  Default (auto-named, 24fps, Twitter-optimized):
    ./create_twitter_video.sh

  Custom name:
    ./create_twitter_video.sh --output my_grind_session.mp4

  Different framerate:
    ./create_twitter_video.sh --framerate 30

  From a specific folder:
    ./create_twitter_video.sh --input custom_imgs/ --output custom.mp4

════════════════════════════════════════════════════════════════
TIPS FOR GREAT TIMELAPSES
════════════════════════════════════════════════════════════════

LIGHTING:
  ✓ Natural light from window is best
  ✓ Consistent lighting throughout session
  ✓ Avoid having window behind you (backlit)
  ✓ If evening: use desk lamp for consistent light

FRAMING:
  ✓ Show upper body + workspace
  ✓ Stable phone position (use stand/tripod)
  ✓ Test framing with ./test_phone_setup.sh first

INTERVALS:
  Default 30s is optimal for 6-8 hour sessions
  
  For shorter sessions, use faster intervals:
    ./record_session.sh --hours 2 --interval 15
  
  For very long sessions, slower intervals:
    ./record_session.sh --hours 12 --interval 45

ENGAGEMENT:
  ✓ 20-40 second videos perform best on Twitter
  ✓ Add engaging caption about what you worked on
  ✓ Use relevant hashtags (#buildinpublic, #studywithme)
  ✓ Post consistently for accountability

BATTERY:
  ✓ ALWAYS keep phone plugged in
  ✓ Streaming uses significant battery
  ✓ 8-hour session will drain battery completely if unplugged

STABILITY:
  ✓ Use phone stand, small tripod, or stack of books
  ✓ Even small movements are very noticeable in timelapse
  ✓ Don't place on desk - desk vibrations will shake video

════════════════════════════════════════════════════════════════
TROUBLESHOOTING DURING RECORDING
════════════════════════════════════════════════════════════════

Stream stopped in Terminal 1:
  → Restart: ./start_phone_stream.sh
  → Recording will auto-reconnect on next frame

Recording failed to find camera:
  → Check if start_phone_stream.sh is still running
  → Verify /dev/video20 exists: ls -la /dev/video20

Computer went to sleep:
  → Disable auto-sleep during recording sessions
  → Or use: sudo systemctl mask sleep.target

Phone disconnected from WiFi:
  → Recording captures up to disconnection point
  → Frames are saved, video can still be created
  → Resume recording with --resume flag if reconnected

Video looks choppy:
  → Normal! That's how timelapses work
  → 30s intervals with normal movement looks smooth at 24fps
  → Slower intervals = choppier video (but shorter recording)

════════════════════════════════════════════════════════════════
ADVANCED USAGE
════════════════════════════════════════════════════════════════

RESUME INTERRUPTED SESSION:
If recording stops early, resume later:
    ./record_session.sh --hours 8
    [Choose "2) Resume from last frame"]

DIFFERENT INTERVALS:
    # Smoother video, longer real-time duration
    ./record_session.sh --hours 6 --interval 20
    
    # More condensed, shorter video
    ./record_session.sh --hours 8 --interval 60

ADD TIMESTAMP OVERLAY:
    uv run capture_timelapse.py \
      --hours 8 --interval 30 \
      --add-timestamp \
      --width 1280 --height 720 \
      --output-dir timelapse_imgs

MULTIPLE SESSIONS PER DAY:
    ./record_session.sh --hours 4 --output-dir morning_session
    ./create_twitter_video.sh --input morning_session --output morning.mp4
    
    ./record_session.sh --hours 4 --output-dir evening_session
    ./create_twitter_video.sh --input evening_session --output evening.mp4

════════════════════════════════════════════════════════════════
STORAGE MANAGEMENT
════════════════════════════════════════════════════════════════

Typical storage per session:
  4 hours @ 30s intervals:  ~480 frames = ~96 MB
  8 hours @ 30s intervals:  ~960 frames = ~192 MB
  Final video:              ~10-50 MB

To free up space after creating video:
    rm -rf timelapse_imgs/*.jpg

Or keep frames for re-encoding later:
    mv timelapse_imgs session_backup_$(date +%Y%m%d)

════════════════════════════════════════════════════════════════

Ready to record? Here's your checklist:

□ Phone positioned and plugged in
□ IP Webcam app running on phone
□ Terminal 1: ./start_phone_stream.sh running
□ Terminal 2: Ready to run ./record_session.sh

Questions? Check PHONE_WEBCAM_SETUP.md for detailed troubleshooting.

Good luck with your session! 🚀

EOF
