#!/bin/bash
# ======================================================
# SETUP SCRIPT – installs rclone + creates upload.sh & batch-upload.sh
# Also ensures all required packages (wget, unzip, bash, nano, curl) are installed.
# Run once on a new instance.
# Then edit ~/.config/rclone/rclone.conf with your keys.
# Use upload.sh for single files, batch-upload.sh for lists.
# ======================================================

set -e

# ---------- 0. Install required packages (skip if present) ----------
install_pkgs() {
    echo "📦 Checking for required packages..."

    # Detect package manager
    if command -v apt-get &>/dev/null; then
        PKG_MANAGER="apt-get"
        INSTALL_CMD="apt-get install -y"
        UPDATE_CMD="apt-get update -qq"
    elif command -v yum &>/dev/null; then
        PKG_MANAGER="yum"
        INSTALL_CMD="yum install -y"
        UPDATE_CMD=""
    elif command -v apk &>/dev/null; then
        PKG_MANAGER="apk"
        INSTALL_CMD="apk add --no-cache"
        UPDATE_CMD=""
    else
        echo "⚠️  No supported package manager found. Please install wget, unzip, bash, nano, and curl manually."
        return
    fi

    # List of required packages
    REQUIRED_PKGS="wget unzip bash nano curl"
    MISSING=""

    for pkg in $REQUIRED_PKGS; do
        if ! command -v "$pkg" &>/dev/null; then
            MISSING="$MISSING $pkg"
        fi
    done

    if [ -n "$MISSING" ]; then
        echo "   Missing packages:$MISSING"
        echo "   Installing with $PKG_MANAGER..."
        [ -n "$UPDATE_CMD" ] && $UPDATE_CMD
        $INSTALL_CMD $MISSING
        echo "✅ Packages installed."
    else
        echo "   All required packages are already installed."
    fi
}

install_pkgs

# ---------- 1. Install rclone if missing ----------
if ! command -v rclone &>/dev/null; then
    echo "📦 rclone not found – installing..."
    wget -q https://downloads.rclone.org/rclone-current-linux-amd64.zip
    unzip -q rclone-current-linux-amd64.zip
    cp rclone-v*-linux-amd64/rclone /usr/local/bin/
    chmod +x /usr/local/bin/rclone
    rm -rf rclone-v*-linux-amd64 rclone-current-linux-amd64.zip
    echo "✅ rclone installed."
else
    echo "✅ rclone already installed."
fi

# ---------- 2. Create placeholder config (if missing) ----------
CONFIG_DIR="$HOME/.config/rclone"
CONFIG_FILE="$CONFIG_DIR/rclone.conf"

mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "🔑 Creating placeholder config – edit with your keys later."
    cat > "$CONFIG_FILE" <<'EOF'
[ia1]
type = internetarchive
access_key_id = YOUR_IA1_ACCESS_KEY
secret_access_key = YOUR_IA1_SECRET_KEY

[ia2]
type = internetarchive
access_key_id = YOUR_IA2_ACCESS_KEY
secret_access_key = YOUR_IA2_SECRET_KEY
EOF
    chmod 600 "$CONFIG_FILE"
    echo "✅ Config created at $CONFIG_FILE"
else
    echo "✅ Config already exists – leaving it untouched."
fi

# ---------- 3. Create upload.sh (single file upload) ----------
cat > ./upload.sh <<'EOF'
#!/bin/bash
# ============================================================
# UPLOAD SCRIPT – stream from URL to Internet Archive via rclone
# Usage: ./upload.sh <public_url> <rclone_remote_path>
# Example: ./upload.sh https://example.com/video.mp4 ia2:/bucket/path/video.mp4
# ============================================================

if [ $# -ne 2 ]; then
    echo "❌ Usage: $0 <public_url> <rclone_remote_path>"
    echo "   Example: $0 https://example.com/video.mp4 ia2:/bucket/path/video.mp4"
    exit 1
fi

URL="$1"
REMOTE="$2"

if [[ ! "$URL" =~ ^https?:// ]]; then
    echo "❌ Invalid URL"
    exit 1
fi
if [[ ! "$REMOTE" =~ : ]]; then
    echo "❌ Invalid remote path (must contain ':')"
    exit 1
fi

echo "⬇️  Streaming from: $URL"
echo "⬆️  Uploading to:   $REMOTE"
echo "⏳ Running..."

set -o pipefail
wget -q -O - "$URL" 2>/dev/null | rclone rcat --progress "$REMOTE"
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Success! File uploaded to $REMOTE"
else
    echo "❌ Failed (exit code $EXIT_CODE)."
    case $EXIT_CODE in
        1)  echo "   → General error (syntax, usage)." ;;
        2)  echo "   → Remote not found or config missing." ;;
        3)  echo "   → Permission denied / authentication issue." ;;
        4)  echo "   → Network error or timeout." ;;
        5)  echo "   → Quota exceeded or rate limit." ;;
        7)  echo "   → Checksum mismatch." ;;
        *)  echo "   → See rclone docs for exit $EXIT_CODE." ;;
    esac
    exit $EXIT_CODE
fi
EOF

chmod +x ./upload.sh
echo "✅ Created: upload.sh"

# ---------- 4. Create batch-upload.sh (batch processing) ----------
cat > ./batch-upload.sh <<'EOF'
#!/bin/bash
# ============================================================
# BATCH UPLOAD – processes a list of URL + remote pairs
# Usage: ./batch-upload.sh <input_file>
# Example: ./batch-upload.sh batch-1.txt
#
# Output:
#   <input_file>-success.txt  (all successful uploads)
#   <input_file>-failed.txt   (all failed uploads)
# ============================================================

if [ $# -ne 1 ]; then
    echo "❌ Usage: $0 <input_file>"
    echo "   Example: $0 batch-1.txt"
    exit 1
fi

INPUT_FILE="$1"

if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ File not found: $INPUT_FILE"
    exit 1
fi

# Generate output filenames based on input file
BASE_NAME="${INPUT_FILE%.txt}"
SUCCESS_FILE="${BASE_NAME}-success.txt"
FAILED_FILE="${BASE_NAME}-failed.txt"

# Clear previous output files
> "$SUCCESS_FILE"
> "$FAILED_FILE"

echo "📤 Processing: $INPUT_FILE"
echo "   Success log: $SUCCESS_FILE"
echo "   Failed log:  $FAILED_FILE"
echo ""

count=0
success=0
failed=0

while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    
    # Split line into URL and remote
    read -r url remote <<< "$line"
    
    if [ -z "$url" ] || [ -z "$remote" ]; then
        echo "⚠️  Skipping malformed line: $line"
        continue
    fi
    
    ((count++))
    echo "--- [#$count] Uploading: $url ---"
    
    if ./upload.sh "$url" "$remote"; then
        echo "✅ [#$count] Success"
        echo "$url $remote" >> "$SUCCESS_FILE"
        ((success++))
    else
        echo "❌ [#$count] FAILED: $url -> $remote"
        echo "$url $remote" >> "$FAILED_FILE"
        ((failed++))
    fi
    echo ""
done < "$INPUT_FILE"

echo "=========================="
echo "📊 Summary:"
echo "   Total processed: $count"
echo "   ✅ Success: $success"
echo "   ❌ Failed:  $failed"
echo ""
echo "📁 Success list saved to: $SUCCESS_FILE"
echo "📁 Failed list saved to:  $FAILED_FILE"
echo ""
if [ $failed -gt 0 ]; then
    echo "🔄 To retry failed uploads, run:"
    echo "   while read -r u r; do ./upload.sh \"\$u\" \"\$r\"; done < $FAILED_FILE"
fi
EOF

chmod +x ./batch-upload.sh
echo "✅ Created: batch-upload.sh"

echo ""
echo "🎉 Setup complete!"
echo "1. Edit $CONFIG_FILE and add your Internet Archive keys:"
echo "   nano $CONFIG_FILE"
echo ""
echo "2. Use upload.sh for a single file:"
echo "   ./upload.sh <url> <remote>"
echo ""
echo "3. Use batch-upload.sh for multiple files:"
echo "   Create a list file (e.g., batch-1.txt) with one 'url remote' per line."
echo "   Then run: ./batch-upload.sh batch-1.txt"
