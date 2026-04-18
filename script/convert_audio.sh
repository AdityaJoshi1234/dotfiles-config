#!/usr/bin/env bash

# Exit immediately if ffmpeg is not installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed. Please install it first." >&2
    exit 1
fi

# Function to handle the actual conversion
convert_to_mp3() {
    local input="$1"

    # Skip if it's not a valid file
    if [ ! -f "$input" ]; then
        echo "Skipping: '$input' is not a valid file."
        return
    fi

    # Extract filename without extension
    local base="${input%.*}"
    
    # Extract extension and convert to lowercase
    local ext="${input##*.}"
    ext="${ext,,}"

    local output="${base}.mp3"

    # If the input is already an MP3, append '_compressed' to prevent overwriting the original
    if [[ "$ext" == "mp3" ]]; then
        output="${base}_compressed.mp3"
    fi

    echo "Processing: '$input' -> '$output'"

    # Run ffmpeg
    # -y: overwrite existing files without asking
    # -v error -stats: keeps terminal output clean but shows progress
    # -codec:a libmp3lame -q:a 2: uses VBR (Variable Bitrate) for high quality (~170-210 kbps). 
    # Change '-q:a 2' to '-b:a 128k' if you want a strict, lower bitrate for maximum compression.
    ffmpeg -y -v error -stats -i "$input" -codec:a libmp3lame -q:a 2 "$output"

    if [ $? -eq 0 ]; then
        echo -e "\nDone: '$output'"
    else
        echo -e "\nFailed to convert: '$input'"
    fi
}

# Main Logic
if [ "$#" -eq 0 ]; then
    # EXTERNAL TRIGGER (No arguments): Convert all audio in the current directory
    echo "No specific file provided. Converting all supported audio files in the current directory..."

    # Enable case-insensitive globbing and prevent literal string output if no files exist
    shopt -s nocaseglob nullglob
    
    # Define supported extensions
    audio_files=(*.flac *.wav *.m4a *.ogg *.wma *.aac *.aiff *.alac *.mp3)

    if [ ${#audio_files[@]} -eq 0 ]; then
        echo "No audio files found in the current directory."
        exit 0
    fi

    for file in "${audio_files[@]}"; do
        # Prevent an infinite loop by skipping files we just created/compressed
        if [[ "$file" == *"_compressed.mp3" ]]; then
            continue
        fi
        convert_to_mp3 "$file"
    done
else
    # INTERNAL TRIGGER (Triggered via lf or passed specific files)
    for file in "$@"; do
        convert_to_mp3 "$file"
    done
fi
