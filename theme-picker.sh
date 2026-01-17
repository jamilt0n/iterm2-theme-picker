#!/usr/bin/env bash

# Theme picker with keyboard navigation and dual favorites system
# favorites.base - tracked in git, syncs across machines
# favorites.local - gitignored, machine-specific additions/removals
#   - Add theme names to include them
#   - Prefix with - to hide themes from base (e.g., "-Nord")

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load config
if [[ -f "$SCRIPT_DIR/config.local" ]]; then
    source "$SCRIPT_DIR/config.local"
elif [[ -f "$SCRIPT_DIR/config.example" ]]; then
    echo "Warning: Using config.example. Copy to config.local and customize."
    sleep 2
    source "$SCRIPT_DIR/config.example"
else
    echo "Error: No config file found. Create config.local from config.example"
    exit 1
fi

# Favorites files
FAVORITES_BASE="$SCRIPT_DIR/favorites.base"
FAVORITES_LOCAL="$SCRIPT_DIR/favorites.local"

# Colors for output
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
RESET='\033[0m'

# Initialize favorites files if they don't exist
touch "$FAVORITES_BASE" 2>/dev/null || true
touch "$FAVORITES_LOCAL" 2>/dev/null || true

# Filter mode: "all", "favorites", "dark", "light"
FILTER_MODE="all"

# Load effective favorites (base + local additions - local removals)
declare -A EFFECTIVE_FAVORITES
declare -A LOCAL_ADDITIONS
declare -A LOCAL_REMOVALS
declare -A BASE_FAVORITES

load_favorites() {
    EFFECTIVE_FAVORITES=()
    LOCAL_ADDITIONS=()
    LOCAL_REMOVALS=()
    BASE_FAVORITES=()

    # Load base favorites
    if [[ -f "$FAVORITES_BASE" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            BASE_FAVORITES["$line"]=1
            EFFECTIVE_FAVORITES["$line"]=1
        done < "$FAVORITES_BASE"
    fi

    # Process local favorites (additions and removals)
    if [[ -f "$FAVORITES_LOCAL" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            if [[ "$line" == -* ]]; then
                # Removal (hide from base)
                local theme="${line:1}"
                LOCAL_REMOVALS["$theme"]=1
                unset 'EFFECTIVE_FAVORITES[$theme]'
            else
                # Addition
                LOCAL_ADDITIONS["$line"]=1
                EFFECTIVE_FAVORITES["$line"]=1
            fi
        done < "$FAVORITES_LOCAL"
    fi
}

load_favorites

# Get all scheme files
load_schemes() {
    SCHEMES=()

    if [[ "$FILTER_MODE" == "favorites" ]]; then
        # Load only effective favorites
        for theme_name in "${!EFFECTIVE_FAVORITES[@]}"; do
            local scheme_file="${SCHEMES_DIR}/${theme_name}.itermcolors"
            if [[ -f "$scheme_file" ]]; then
                SCHEMES+=("$scheme_file")
            fi
        done
        # Sort schemes
        IFS=$'\n' SCHEMES=($(sort <<<"${SCHEMES[*]}")); unset IFS
    else
        # Load all schemes
        while IFS= read -r line; do
            if [[ "$FILTER_MODE" == "all" ]] || is_theme_matching_filter "$line"; then
                SCHEMES+=("$line")
            fi
        done < <(find "$SCHEMES_DIR" -name "*.itermcolors" 2>/dev/null | sort)
    fi

    TOTAL=${#SCHEMES[@]}
}

# Check if theme matches current filter (dark/light)
is_theme_matching_filter() {
    local scheme_file="$1"
    local filename=$(basename "$scheme_file")
    local filename_lower=$(echo "$filename" | tr '[:upper:]' '[:lower:]')

    if [[ "$FILTER_MODE" == "dark" ]]; then
        if echo "$filename_lower" | grep -q "dark\|night\|black\|dusk\|midnight"; then
            return 0
        elif echo "$filename_lower" | grep -q "light\|day\|bright"; then
            return 1
        fi
        return 0
    elif [[ "$FILTER_MODE" == "light" ]]; then
        if echo "$filename_lower" | grep -q "light\|day\|bright\|dawn"; then
            return 0
        elif echo "$filename_lower" | grep -q "dark\|night\|black\|dusk"; then
            return 1
        fi
        return 0
    fi
    return 0
}

load_schemes
CURRENT=1

get_theme_name() {
    basename "$1" .itermcolors
}

is_effective_favorite() {
    local theme_name="$1"
    [[ -n "${EFFECTIVE_FAVORITES[$theme_name]:-}" ]]
}

is_base_favorite() {
    local theme_name="$1"
    [[ -n "${BASE_FAVORITES[$theme_name]:-}" ]]
}

is_local_addition() {
    local theme_name="$1"
    [[ -n "${LOCAL_ADDITIONS[$theme_name]:-}" ]]
}

is_local_removal() {
    local theme_name="$1"
    [[ -n "${LOCAL_REMOVALS[$theme_name]:-}" ]]
}

# Add to local favorites
add_local() {
    local theme_name="$1"
    if ! is_local_addition "$theme_name" && ! is_base_favorite "$theme_name"; then
        echo "$theme_name" >> "$FAVORITES_LOCAL"
        load_favorites
        return 0
    fi
    return 1
}

# Add to base favorites (syncs across machines)
add_base() {
    local theme_name="$1"
    if ! is_base_favorite "$theme_name"; then
        echo "$theme_name" >> "$FAVORITES_BASE"
        # Remove from local additions if it was there
        if is_local_addition "$theme_name"; then
            grep -vxF "$theme_name" "$FAVORITES_LOCAL" > "${FAVORITES_LOCAL}.tmp" && \
                mv "${FAVORITES_LOCAL}.tmp" "$FAVORITES_LOCAL"
        fi
        load_favorites
        return 0
    fi
    return 1
}

# Remove from favorites (local hide if in base, full remove if local-only)
remove_favorite() {
    local theme_name="$1"

    if is_local_addition "$theme_name"; then
        # Remove from local additions
        grep -vxF "$theme_name" "$FAVORITES_LOCAL" > "${FAVORITES_LOCAL}.tmp" && \
            mv "${FAVORITES_LOCAL}.tmp" "$FAVORITES_LOCAL"
        load_favorites
        return 0
    elif is_base_favorite "$theme_name" && ! is_local_removal "$theme_name"; then
        # Add to local removals (hide from this machine)
        echo "-$theme_name" >> "$FAVORITES_LOCAL"
        load_favorites
        return 0
    fi
    return 1
}

# Unhide a locally-hidden base favorite
unhide_favorite() {
    local theme_name="$1"
    if is_local_removal "$theme_name"; then
        grep -vxF "-$theme_name" "$FAVORITES_LOCAL" > "${FAVORITES_LOCAL}.tmp" && \
            mv "${FAVORITES_LOCAL}.tmp" "$FAVORITES_LOCAL"
        load_favorites
        return 0
    fi
    return 1
}

show_help() {
    clear
    printf "${BOLD}${CYAN}iTerm Theme Picker${RESET}\n\n"
    printf "${BOLD}Navigation:${RESET}\n"
    printf "  ${BLUE}n/Space/Enter${RESET}  Next theme\n"
    printf "  ${BLUE}p${RESET}              Previous theme\n"
    printf "  ${BLUE}j${RESET}              Jump to theme number\n"
    printf "\n"
    printf "${BOLD}Favorites:${RESET}\n"
    printf "  ${GREEN}s${RESET}              Save to ${MAGENTA}local${RESET} favorites (this machine only)\n"
    printf "  ${GREEN}S${RESET}              Save to ${CYAN}base${RESET} favorites (syncs across machines)\n"
    printf "  ${RED}x${RESET}              Remove/hide from favorites\n"
    printf "  ${YELLOW}u${RESET}              Unhide (if hidden locally)\n"
    printf "\n"
    printf "${BOLD}Actions:${RESET}\n"
    printf "  ${GREEN}i${RESET}              Install current theme to iTerm2\n"
    printf "\n"
    printf "${BOLD}Filters:${RESET}\n"
    printf "  ${YELLOW}f${RESET}              Toggle favorites-only mode\n"
    printf "  ${YELLOW}d${RESET}              Show dark themes only\n"
    printf "  ${YELLOW}L${RESET}              Show light themes only\n"
    printf "  ${YELLOW}a${RESET}              Show all themes\n"
    printf "\n"
    printf "${BOLD}Other:${RESET}\n"
    printf "  ${YELLOW}l${RESET}              List all favorites\n"
    printf "  ${YELLOW}h${RESET}              Show this help\n"
    printf "  ${RED}q${RESET}              Quit\n"
    printf "\n"
    printf "${BOLD}Favorites System:${RESET}\n"
    printf "  ${CYAN}base${RESET}  = syncs via git (favorites.base)\n"
    printf "  ${MAGENTA}local${RESET} = this machine only (favorites.local, gitignored)\n"
    printf "  Prefix with ${RED}-${RESET} in local to hide base themes\n"
    printf "\n"
    printf "${BOLD}Current filter:${RESET} $FILTER_MODE\n"
    printf "\nPress any key to continue..."
    read -n 1 -s
}

list_favorites() {
    clear
    printf "${BOLD}${CYAN}Favorite Themes:${RESET}\n\n"

    if [[ ${#EFFECTIVE_FAVORITES[@]} -eq 0 ]]; then
        echo "No favorites yet!"
    else
        printf "${BOLD}Effective favorites (what you see):${RESET}\n"
        for theme in "${!EFFECTIVE_FAVORITES[@]}"; do
            if is_base_favorite "$theme"; then
                printf "  ${CYAN}[base]${RESET}  $theme\n"
            else
                printf "  ${MAGENTA}[local]${RESET} $theme\n"
            fi
        done | sort -t']' -k2

        if [[ ${#LOCAL_REMOVALS[@]} -gt 0 ]]; then
            printf "\n${BOLD}Hidden on this machine:${RESET}\n"
            for theme in "${!LOCAL_REMOVALS[@]}"; do
                printf "  ${RED}[hidden]${RESET} $theme\n"
            done | sort
        fi
    fi

    printf "\n${BOLD}Press any key to continue...${RESET}"
    read -n 1 -s
}

jump_to_theme() {
    clear
    printf "${BOLD}${CYAN}Jump to Theme${RESET}\n\n"
    printf "Enter theme number (1-${TOTAL}): "
    read -r num
    if [[ "$num" =~ ^[0-9]+$ ]] && ((num >= 1 && num <= TOTAL)); then
        CURRENT=$num
    else
        printf "${RED}Invalid number${RESET}\n"
        sleep 1
    fi
}

install_theme() {
    local scheme_file="$1"
    local theme_name
    theme_name=$(get_theme_name "$scheme_file")

    clear
    printf "${BOLD}${CYAN}Installing: ${theme_name}${RESET}\n\n"

    if "$SCRIPT_DIR/import-scheme.sh" "$theme_name" 2>&1; then
        printf "\n${GREEN}Installed! Restart iTerm2 to see it in Color Presets${RESET}\n"
    else
        printf "\n${RED}Installation failed${RESET}\n"
    fi

    printf "\nPress any key to continue..."
    read -n 1 -s
}

display_theme() {
    local index="$1"
    local scheme_file="${SCHEMES[$((index - 1))]}"
    local theme_name
    theme_name=$(get_theme_name "$scheme_file")
    local fav_marker=""
    local status_info=""

    if is_effective_favorite "$theme_name"; then
        if is_base_favorite "$theme_name"; then
            fav_marker="${CYAN}[base] ${RESET}"
        else
            fav_marker="${MAGENTA}[local] ${RESET}"
        fi
    elif is_local_removal "$theme_name"; then
        fav_marker="${RED}[hidden] ${RESET}"
    fi

    # Apply the theme
    "$SCRIPT_DIR/preview.rb" "$scheme_file" 2>/dev/null || true
    sleep 0.1

    clear
    printf "\n\n"
    printf "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${RESET}\n"
    printf "${BOLD}  ${fav_marker}${theme_name}${RESET}\n"
    printf "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${RESET}\n\n"
    printf "${BOLD}Theme ${index}/${TOTAL}${RESET}"
    if [[ "$FILTER_MODE" != "all" ]]; then
        printf " ${YELLOW}(filter: ${FILTER_MODE})${RESET}"
    fi
    printf "\n\n"

    # Display color preview
    printf "${BOLD}Text Styles:${RESET}\n"
    printf "  Normal text  \033[1mBold text\033[0m  \033[2mDim text\033[0m  \033[3mItalic text\033[0m  \033[4mUnderlined\033[0m\n\n"

    printf "${BOLD}ANSI Colors:${RESET}\n"
    printf "  \033[30m■\033[0m Black    \033[31m■\033[0m Red      \033[32m■\033[0m Green    \033[33m■\033[0m Yellow\n"
    printf "  \033[34m■\033[0m Blue     \033[35m■\033[0m Magenta  \033[36m■\033[0m Cyan     \033[37m■\033[0m White\n\n"

    printf "${BOLD}Bright Colors:${RESET}\n"
    printf "  \033[90m■\033[0m Bright Black    \033[91m■\033[0m Bright Red\n"
    printf "  \033[92m■\033[0m Bright Green    \033[93m■\033[0m Bright Yellow\n"
    printf "  \033[94m■\033[0m Bright Blue     \033[95m■\033[0m Bright Magenta\n"
    printf "  \033[96m■\033[0m Bright Cyan     \033[97m■\033[0m Bright White\n\n"

    printf "${BOLD}Sample Code:${RESET}\n"
    printf "  \033[35mfunction\033[0m \033[33mgreet\033[0m() {\n"
    printf "    \033[36mconst\033[0m \033[37mmessage\033[0m = \033[32m\"Hello, World!\"\033[0m;\n"
    printf "    \033[36mconsole\033[0m.\033[33mlog\033[0m(message);  \033[90m// Log greeting\033[0m\n"
    printf "  }\n\n"

    printf "${BOLD}Controls:${RESET} ${GREEN}[s]${RESET}local ${GREEN}[S]${RESET}base ${RED}[x]${RESET}remove ${YELLOW}[u]${RESET}nhide ${GREEN}[i]${RESET}nstall ${BLUE}[n]${RESET}ext ${BLUE}[p]${RESET}rev ${YELLOW}[f]${RESET}avs ${YELLOW}[h]${RESET}elp ${RED}[q]${RESET}uit\n\n"
}

show_message() {
    local color="$1"
    local message="$2"
    printf "\r${color}${message}${RESET}"
    sleep 0.5
    printf "\r%80s\r" ""
}

# Main loop
show_help

while true; do
    if ((TOTAL == 0)); then
        clear
        printf "${RED}No themes found matching filter: ${FILTER_MODE}${RESET}\n\n"
        printf "Press [a] for all themes, [h] for help, or [q] to quit\n"
        read -n 1 -s input
        case "$input" in
            a|A)
                FILTER_MODE="all"
                load_schemes
                CURRENT=1
                continue
                ;;
            h|H)
                show_help
                continue
                ;;
            q|Q)
                exit 0
                ;;
        esac
        continue
    fi

    display_theme "$CURRENT"

    scheme_file="${SCHEMES[$((CURRENT - 1))]}"
    theme_name=$(get_theme_name "$scheme_file")

    read -n 1 -s input

    case "$input" in
        s)
            # Save to local
            if add_local "$theme_name"; then
                show_message "$MAGENTA" "Added to local favorites!"
            elif is_effective_favorite "$theme_name"; then
                show_message "$YELLOW" "Already in favorites"
            else
                show_message "$YELLOW" "Already in base (use S to update)"
            fi
            ;;
        S)
            # Save to base (syncs)
            if add_base "$theme_name"; then
                show_message "$CYAN" "Added to base favorites (will sync)!"
            else
                show_message "$YELLOW" "Already in base favorites"
            fi
            ;;
        x|X)
            if remove_favorite "$theme_name"; then
                if is_base_favorite "$theme_name"; then
                    show_message "$RED" "Hidden on this machine"
                else
                    show_message "$RED" "Removed from favorites"
                fi
            else
                show_message "$YELLOW" "Not in favorites"
            fi
            ;;
        u|U)
            if unhide_favorite "$theme_name"; then
                show_message "$GREEN" "Unhidden!"
            else
                show_message "$YELLOW" "Not hidden"
            fi
            ;;
        i|I)
            install_theme "$scheme_file"
            ;;
        n|N|''|' ')
            if ((CURRENT < TOTAL)); then
                ((CURRENT++))
            else
                clear
                printf "${BOLD}${GREEN}════════════════════════════════════════════════════${RESET}\n"
                printf "${BOLD}Reached the end of all themes!${RESET}\n"
                printf "${BOLD}${GREEN}════════════════════════════════════════════════════${RESET}\n\n"
                if [[ ${#EFFECTIVE_FAVORITES[@]} -gt 0 ]]; then
                    printf "${BOLD}Your favorites (${#EFFECTIVE_FAVORITES[@]}):${RESET}\n"
                    for theme in "${!EFFECTIVE_FAVORITES[@]}"; do
                        echo "  $theme"
                    done | sort
                else
                    echo "No favorites selected."
                fi
                printf "\n${BOLD}Press [p] to go back, [l] to list favorites, or [q] to quit${RESET}\n"
                read -n 1 -s input
                case "$input" in
                    p|P) ;;
                    l|L) list_favorites ;;
                    *) exit 0 ;;
                esac
            fi
            ;;
        p|P)
            if ((CURRENT > 1)); then
                ((CURRENT--))
            fi
            ;;
        j|J)
            jump_to_theme
            ;;
        f|F)
            if [[ "$FILTER_MODE" == "favorites" ]]; then
                FILTER_MODE="all"
            else
                FILTER_MODE="favorites"
            fi
            load_schemes
            CURRENT=1
            ;;
        d|D)
            FILTER_MODE="dark"
            load_schemes
            CURRENT=1
            ;;
        L)
            FILTER_MODE="light"
            load_schemes
            CURRENT=1
            ;;
        a|A)
            FILTER_MODE="all"
            load_schemes
            CURRENT=1
            ;;
        l)
            list_favorites
            ;;
        h|H|\?)
            show_help
            ;;
        q|Q)
            clear
            printf "${BOLD}${GREEN}Favorites saved!${RESET}\n\n"
            printf "  ${CYAN}Base (syncs):${RESET}  $FAVORITES_BASE\n"
            printf "  ${MAGENTA}Local (here):${RESET}  $FAVORITES_LOCAL\n"
            if [[ ${#EFFECTIVE_FAVORITES[@]} -gt 0 ]]; then
                printf "\n${BOLD}Your effective favorites:${RESET}\n"
                for theme in "${!EFFECTIVE_FAVORITES[@]}"; do
                    echo "  $theme"
                done | sort
            fi
            printf "\n"
            exit 0
            ;;
        *)
            ;;
    esac
done
