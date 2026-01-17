#!/usr/bin/env bash

# Import all effective favorites (base + local - hidden) into iTerm2

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load config
if [[ -f "$SCRIPT_DIR/config.local" ]]; then
    source "$SCRIPT_DIR/config.local"
elif [[ -f "$SCRIPT_DIR/config.example" ]]; then
    echo "Warning: Using config.example. Copy to config.local and customize."
    source "$SCRIPT_DIR/config.example"
else
    echo "Error: No config file found."
    exit 1
fi

FAVORITES_BASE="$SCRIPT_DIR/favorites.base"
FAVORITES_LOCAL="$SCRIPT_DIR/favorites.local"

# Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
RESET='\033[0m'

# Build effective favorites list
declare -A effective_favorites
declare -A local_removals

# Load base
if [[ -f "$FAVORITES_BASE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        effective_favorites["$line"]=1
    done < "$FAVORITES_BASE"
fi

# Process local (additions and removals)
if [[ -f "$FAVORITES_LOCAL" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        if [[ "$line" == -* ]]; then
            local theme="${line:1}"
            local_removals["$theme"]=1
            unset 'effective_favorites[$theme]'
        else
            effective_favorites["$line"]=1
        fi
    done < "$FAVORITES_LOCAL"
fi

if [[ ${#effective_favorites[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No favorites to import${RESET}"
    echo "Add favorites using theme-picker.sh first"
    exit 0
fi

echo -e "${BOLD}${GREEN}Importing ${#effective_favorites[@]} favorite themes...${RESET}\n"

themes_to_import=()
for theme_name in "${!effective_favorites[@]}"; do
    echo -e "${GREEN}${RESET} $theme_name"
    themes_to_import+=("$theme_name")
done

echo ""

# Import all at once
"$SCRIPT_DIR/import-scheme.sh" "${themes_to_import[@]}"

echo ""
echo -e "${BOLD}${GREEN}Done!${RESET}"
echo -e "${YELLOW}Restart iTerm2 to see the new color presets${RESET}"
