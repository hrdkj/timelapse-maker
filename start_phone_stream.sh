#!/bin/bash

# Script to stream IP Webcam from Android phone to virtual webcam device
# This creates a virtual webcam at /dev/video20 that can be used by OpenCV

set -e

echo "=== IP Webcam to Virtual Device Setup ==="
echo ""

# Check if v4l2loopback is installed
if ! modinfo v4l2loopback &>/dev/null; then
    echo "ERROR: v4l2loopback kernel module not found!"
    echo "Please install it first with:"
    echo "  sudo pacman -S v4l2loopback-dkms"
    echo "  (or from AUR: yay -S v4l2loopback-dkms)"
    exit 1
fi

# Check if ffmpeg is installed
if ! command -v ffmpeg &>/dev/null; then
    echo "ERROR: ffmpeg not found!"
    echo "Please install it with: sudo pacman -S ffmpeg"
    exit 1
fi

# Load v4l2loopback module if not already loaded
if ! lsmod | grep -q v4l2loopback; then
    echo "Loading v4l2loopback kernel module..."
    sudo modprobe v4l2loopback devices=1 video_nr=20 card_label="IPWebcam"
    echo "Virtual webcam created at /dev/video20"
else
    echo "v4l2loopback module already loaded"
fi

# Verify the device exists
if [ ! -e /dev/video20 ]; then
    echo "ERROR: /dev/video20 does not exist!"
    echo "Try reloading the module:"
    echo "  sudo modprobe -r v4l2loopback"
    echo "  sudo modprobe v4l2loopback devices=1 video_nr=20 card_label=\"IPWebcam\""
    exit 1
fi

echo ""
echo "Virtual webcam ready at /dev/video20"
echo ""

PHONE_IP="192.168.31.154"

echo "Connecting to http://$PHONE_IP:8080/video..."

echo ""
echo "Starting ffmpeg stream from phone to /dev/video20..."
echo "This will run in the background. Press Ctrl+C to stop."
echo ""

# Stream from IP Webcam to virtual device
# -f mjpeg: Input format from IP Webcam
# -i: Input URL
# -vcodec rawvideo: Output raw video for v4l2
# -pix_fmt yuyv422: Pixel format compatible with most applications
# -f v4l2: Output to v4l2 device
ffmpeg -f mjpeg \
    -i "http://$PHONE_IP:8080/video" \
    -vcodec rawvideo \
    -pix_fmt yuyv422 \
    -f v4l2 \
    /dev/video20

# If ffmpeg exits, show message
echo ""
echo "Stream stopped."
echo "To restart, run: ./start_phone_stream.sh"
