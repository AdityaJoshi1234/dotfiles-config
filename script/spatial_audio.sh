#!/bin/bash
#
# spatial_audio.sh - Convert an audio file to a circular binaural panning effect.
# Usage: ./spatial_audio.sh input.mp3 [output.mp3] [period_seconds]
#
# The effect makes the sound travel from ear to ear in a circular fashion.
# Period defaults to 5 seconds if not given.
#

set -e

DEFAULT_PERIOD=5

usage() {
    cat <<EOF
Usage: $0 input.mp3 [output.mp3] [period_seconds]

Converts an audio file to a stereo track with circular panning
(left ↔ right) using a sine/cosine modulation.

Arguments:
  input.mp3         Input audio file (any format supported by ffmpeg)
  output.mp3        Output file (default: input_binaural.ext)
  period_seconds    Duration of one full left-right cycle (default: $DEFAULT_PERIOD)

Example:
  $0 song.mp3 song_spatial.mp3 3.5
EOF
    exit 1
}

# Check for ffmpeg
if ! command -v ffmpeg &>/dev/null; then
    echo "Error: ffmpeg not found in PATH. Please install ffmpeg."
    exit 1
fi

# Parse arguments
if [ $# -lt 1 ]; then
    usage
fi

INPUT="$1"
if [ ! -f "$INPUT" ]; then
    echo "Error: Input file '$INPUT' does not exist."
    exit 1
fi

# Determine output filename
if [ $# -ge 2 ]; then
    OUTPUT="$2"
else
    BASENAME=$(basename "$INPUT")
    DIRNAME=$(dirname "$INPUT")
    OUTPUT="${DIRNAME}/${BASENAME%.*}_binaural.${BASENAME##*.}"
fi

# Determine period
PERIOD="$DEFAULT_PERIOD"
if [ $# -ge 3 ]; then
    PERIOD="$3"
    # Validate that period is a positive number
    if ! [[ "$PERIOD" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [ "$(echo "$PERIOD <= 0" | bc 2>/dev/null)" = "1" ]; then
        echo "Error: Period must be a positive number (e.g., 5 or 3.5)."
        exit 1
    fi
fi

echo "Input:  $INPUT"
echo "Output: $OUTPUT"
echo "Period: $PERIOD seconds per rotation"

# Build the filter.
# 1. Downmix to mono using -ac 1 (handles any input channel count).
# 2. Apply dynamic panning with time‑varying gains.
#    The gain is scaled by 0.9 to prevent clipping.
#    The filter uses sin/cos with period PERIOD.
FILTER="pan=stereo|c0=0.9*sin(2*PI*t/$PERIOD)*c0|c1=0.9*cos(2*PI*t/$PERIOD)*c0"

# Run ffmpeg
ffmpeg -i "$INPUT" -ac 1 -af "$FILTER" -ac 2 "$OUTPUT"

echo "Done! The output file is ready."