#!/usr/bin/env bash
# catbox-upload.sh
# Batch upload images from a directory to catbox.moe
# Requires: catbox (AUR) — https://aur.archlinux.org/packages/catbox

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
# Your catbox.moe userhash. Find it at: https://catbox.moe/user/manage.php
# You can hardcode it here, set the env var CATBOX_USER_HASH, or pass via -u flag.
USERHASH="${CATBOX_USER_HASH:-}"

# Supported image extensions (lowercase; matched case-insensitively)
IMAGE_EXTS=("jpg" "jpeg" "png" "gif" "webp" "bmp" "tiff" "tif" "avif" "svg")

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── Helper functions ─────────────────────────────────────────────────────────
usage() {
    cat <<EOF
${BOLD}Usage:${RESET}
  $(basename "$0") [OPTIONS] <directory>

${BOLD}Options:${RESET}
  -u <userhash>   Your catbox.moe userhash (overrides CATBOX_USER_HASH env var)
  -r              Recurse into subdirectories
  -l <file>       Save uploaded URLs to a log file
  -d              Dry run — list files that would be uploaded without uploading
  -h              Show this help message

${BOLD}Examples:${RESET}
  $(basename "$0") ~/Pictures
  $(basename "$0") -u abc123 -r ~/Screenshots
  $(basename "$0") -l urls.txt ~/Photos
  CATBOX_USER_HASH=abc123 $(basename "$0") ~/Images

${BOLD}Notes:${RESET}
  - Your userhash can be found at https://catbox.moe/user/manage.php
  - Set CATBOX_USER_HASH in your shell profile to avoid passing it every time.
EOF
    exit 0
}

log_info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

is_image() {
    local file="$1"
    local ext="${file##*.}"
    ext="${ext,,}"  # lowercase
    for e in "${IMAGE_EXTS[@]}"; do
        [[ "$ext" == "$e" ]] && return 0
    done
    return 1
}

# ─── Argument parsing ─────────────────────────────────────────────────────────
RECURSE=false
LOG_FILE=""
DRY_RUN=false

while getopts ":u:rl:dh" opt; do
    case $opt in
        u) USERHASH="$OPTARG" ;;
        r) RECURSE=true ;;
        l) LOG_FILE="$OPTARG" ;;
        d) DRY_RUN=true ;;
        h) usage ;;
        :) log_error "Option -$OPTARG requires an argument."; exit 1 ;;
        \?) log_error "Unknown option: -$OPTARG"; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

# ─── Validate inputs ──────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
    log_error "No directory specified."
    echo "Run '$(basename "$0") -h' for usage."
    exit 1
fi

TARGET_DIR="${1%/}"  # strip trailing slash

if [[ ! -d "$TARGET_DIR" ]]; then
    log_error "Directory not found: $TARGET_DIR"
    exit 1
fi

if ! command -v catbox &>/dev/null; then
    log_error "'catbox' command not found."
    log_error "Install it from the AUR: yay -S catbox  (or paru/makepkg)"
    exit 1
fi

if [[ -z "$USERHASH" ]]; then
    log_warn "No userhash provided — files will be uploaded anonymously."
    log_warn "Set CATBOX_USER_HASH or use -u <hash> to link uploads to your account."
fi

# ─── Collect image files ──────────────────────────────────────────────────────
mapfile -t FILES < <(
    if $RECURSE; then
        find "$TARGET_DIR" -type f | sort
    else
        find "$TARGET_DIR" -maxdepth 1 -type f | sort
    fi
)

IMAGE_FILES=()
for f in "${FILES[@]}"; do
    is_image "$f" && IMAGE_FILES+=("$f")
done

if [[ ${#IMAGE_FILES[@]} -eq 0 ]]; then
    log_warn "No image files found in: $TARGET_DIR"
    exit 0
fi

log_info "Found ${BOLD}${#IMAGE_FILES[@]}${RESET} image(s) in ${BOLD}${TARGET_DIR}${RESET}"
$RECURSE   && log_info "Recursive mode enabled."
$DRY_RUN   && log_info "${YELLOW}Dry-run mode — nothing will be uploaded.${RESET}"
[[ -n "$LOG_FILE" ]] && log_info "URLs will be saved to: $LOG_FILE"

# ─── Upload loop ──────────────────────────────────────────────────────────────
SUCCESS=0
FAILED=0
URLS=()

for img in "${IMAGE_FILES[@]}"; do
    filename="$(basename "$img")"

    if $DRY_RUN; then
        log_info "[dry-run] Would upload: $filename"
        continue
    fi

    echo -ne "  Uploading ${BOLD}${filename}${RESET} ... "

    # Build the catbox command depending on whether a userhash was provided
    if [[ -n "$USERHASH" ]]; then
        url=$(catbox upload "$img" --user "$USERHASH" 2>&1) || true
    else
        url=$(catbox upload "$img" 2>&1) || true
    fi

    # catbox returns a URL on success; anything else is an error
    if [[ "$url" == https://files.catbox.moe/* ]]; then
        echo -e "${GREEN}${url}${RESET}"
        URLS+=("$url")
        (( SUCCESS++ )) || true
    else
        echo -e "${RED}FAILED${RESET}"
        log_error "  Response: $url"
        (( FAILED++ )) || true
    fi
done

# ─── Write log file ───────────────────────────────────────────────────────────
if [[ -n "$LOG_FILE" && ${#URLS[@]} -gt 0 ]]; then
    printf '%s\n' "${URLS[@]}" >> "$LOG_FILE"
    log_ok "Saved ${#URLS[@]} URL(s) to $LOG_FILE"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
if ! $DRY_RUN; then
    echo -e "${BOLD}── Summary ──────────────────────────────${RESET}"
    echo -e "  ${GREEN}Uploaded : $SUCCESS${RESET}"
    [[ $FAILED -gt 0 ]] && echo -e "  ${RED}Failed   : $FAILED${RESET}"
    echo ""
fi

[[ $FAILED -gt 0 ]] && exit 1 || exit 0
