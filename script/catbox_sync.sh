#!/usr/bin/env bash

# --- Configuration ---
export CATBOX_USER_HASH="09201286f061f4b448c2ba626" # Optional: Remove if using bashrc method
UPLOAD_CMD=(catbox) 
MAX_SIZE_BYTES=209715200 

# --- Directory Setup ---
DIR_UPLOADED="uploaded"
DIR_ERROR="non_uploaded/error"
DIR_TOOBIG="non_uploaded/too_big"

mkdir -p "$DIR_UPLOADED" "$DIR_ERROR" "$DIR_TOOBIG"

# --- Dependency Check ---
for cmd in "${UPLOAD_CMD[0]}" ffmpeg stat; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: '$cmd' is not installed."
        exit 1
    fi
done

echo "Starting Catbox upload and sorting process..."

shopt -s nocaseglob nullglob
video_files=(*.mp4 *.mkv *.webm *.mov *.avi *.flv *.wmv *.m4v)

if [ ${#video_files[@]} -eq 0 ]; then
    echo "No video files found in the current directory."
    exit 0
fi

for original_file in "${video_files[@]}"; do
    [ -f "$original_file" ] || continue

    echo -e "\n--------------------------------------------------"
    echo "Processing: $original_file"

    # Extract extension to check if it's already an MP4
    ext="${original_file##*.}"
    ext="${ext,,}" # Convert to lowercase
    base="${original_file%.*}"

    upload_target="$original_file"
    temp_mp4=""

    # 1. Fast-Convert to MP4 if necessary
    if [[ "$ext" != "mp4" ]]; then
        temp_mp4="${base}_temp_upload.mp4"
        echo "Repackaging into MP4 container (No transcoding)..."
        
        # -c copy grabs the existing streams and places them in the MP4 container
        if ! ffmpeg -y -v error -stats -i "$original_file" -c copy "$temp_mp4"; then
            echo "Status: Error (Failed to copy streams to MP4 format. Incompatible codecs?)"
            mv "$original_file" "$DIR_ERROR/"
            rm -f "$temp_mp4"
            continue
        fi
        
        # Change the file we are targeting for upload and size-checking
        upload_target="$temp_mp4"
    fi

    # 2. Check file size (of the file we are actually uploading)
    file_size=$(stat -c%s "$upload_target")
    
    if [ "$file_size" -gt "$MAX_SIZE_BYTES" ]; then
        human_size=$(numfmt --to=iec-i --suffix=B --format="%.2f" "$file_size")
        echo "Status: Skipped (Converted file is $human_size, exceeding 200MB limit)"
        
        # Move the original file and delete the temporary MP4
        mv "$original_file" "$DIR_TOOBIG/"
        [[ -n "$temp_mp4" ]] && rm -f "$temp_mp4"
        continue
    fi

    # 3. Upload file
    echo "Uploading $upload_target..."
    response=$("${UPLOAD_CMD[@]}" "$upload_target" 2>&1)
    exit_code=$?

    # 4. Evaluate success and sort the ORIGINAL file
    if [ $exit_code -eq 0 ] && [[ "$response" == *"catbox.moe"* ]]; then
        echo "Status: Success!"
        echo "Link: $response"
        
        echo "$original_file - $response" >> "$DIR_UPLOADED/catbox_links.txt"
        mv "$original_file" "$DIR_UPLOADED/"
    else
        echo "Status: Error!"
        echo "Exit Code: $exit_code"
        echo "Details: $response"
        
        mv "$original_file" "$DIR_ERROR/"
    fi

    # 5. Cleanup the temporary MP4 file regardless of success or failure
    if [[ -n "$temp_mp4" ]]; then
        echo "Cleaning up temporary MP4..."
        rm -f "$temp_mp4"
    fi

done

shopt -u nocaseglob nullglob

echo -e "\n--------------------------------------------------"
echo "Finished! Processed videos have been sorted."
