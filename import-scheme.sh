#!/usr/bin/env bash

# Import iTerm color schemes into iTerm2 preferences
# Adapted from iTerm2-Color-Schemes

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Fatal error: this script is for iTerm on macOS only." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load config
if [[ -f "$SCRIPT_DIR/config.local" ]]; then
    source "$SCRIPT_DIR/config.local"
elif [[ -f "$SCRIPT_DIR/config.example" ]]; then
    echo "Warning: Using config.example. Copy to config.local and customize." >&2
    source "$SCRIPT_DIR/config.example"
else
    echo "Error: No config file found. Create config.local from config.example" >&2
    exit 1
fi

# Parse arguments
VERBOSE=false
while getopts 'vh' OPT; do
    case $OPT in
    v)
        VERBOSE=true
        ;;
    h)
        echo "Usage: $(basename "$0") [-h] [-v] [scheme ...] [file ...]"
        exit
        ;;
    *)
        echo "Usage: $(basename "$0") [-h] [-v] [scheme ...] [file ...]"
        exit 128
        ;;
    esac
done
shift $(($OPTIND - 1))

if (($# == 0)); then
    echo "Usage: $(basename "$0") [-h] [-v] [scheme ...] [file ...]" >&2
    exit 2
fi

# Pretty print function
function echo_and_eval() {
    if $VERBOSE; then
        echo "\$ $@"
    fi
    eval "$@"
}

# Download the default iTerm configuration file if not exists
if [[ ! -s "$HOME/Library/Preferences/com.googlecode.iterm2.plist" ]]; then
    echo "Downloading the default iTerm configuration file ..."
    echo_and_eval "curl -fL# -o \"\$HOME/Library/Preferences/com.googlecode.iterm2.plist\" \\
            https://github.com/gnachman/iTerm2/raw/master/plists/iTerm2.plist"
fi

# Create 'Custom Color Presets' entry if not exists
if ! /usr/libexec/PlistBuddy -c 'Print "Custom Color Presets"' \
    "$HOME/Library/Preferences/com.googlecode.iterm2.plist" &>/dev/null; then
    echo "Creating 'Custom Color Presets' entry ..."
    echo_and_eval "/usr/libexec/PlistBuddy \\
                -c 'Add \"Custom Color Presets\" dict' \\
                \"\$HOME/Library/Preferences/com.googlecode.iterm2.plist\""
fi

# Import color schemes for iTerm
count=0
for filename in "$@"; do
    count=$((count + 1))

    # Handle various input formats
    if [[ "$filename" == *.itermcolors ]]; then
        # Already a full path or filename with extension
        if [[ ! -f "$filename" ]]; then
            filename="${SCHEMES_DIR}/$(basename "$filename")"
        fi
    else
        # Just a theme name
        filename="${SCHEMES_DIR}/${filename}.itermcolors"
    fi

    if [[ ! -f "$filename" ]]; then
        echo "File not found: \"$filename\". Skip." >&2
        continue
    fi

    # Format the scheme name (capitalized)
    name="$(basename "$filename" .itermcolors)"

    # Import the color scheme
    echo "Importing color scheme ($count/$#): $name ..."
    if /usr/libexec/PlistBuddy -c "Print \"Custom Color Presets:$name\"" \
        "$HOME/Library/Preferences/com.googlecode.iterm2.plist" &>/dev/null; then
        # Already installed - delete and reinstall
        echo_and_eval "/usr/libexec/PlistBuddy \\
                -c 'Delete \"Custom Color Presets:$name\"' \\
                -c 'Add \"Custom Color Presets:$name\" dict' \\
                -c 'Merge \"$filename\" \"Custom Color Presets:$name\"' \\
                \"\$HOME/Library/Preferences/com.googlecode.iterm2.plist\""
    else
        # Not installed - install directly
        echo_and_eval "/usr/libexec/PlistBuddy \\
                -c 'Add \"Custom Color Presets:$name\" dict' \\
                -c 'Merge \"$filename\" \"Custom Color Presets:$name\"' \\
                \"\$HOME/Library/Preferences/com.googlecode.iterm2.plist\""
    fi
done
