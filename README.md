# iterm2-theme-picker

Interactive theme picker for iTerm2 with a dual favorites system that syncs across machines.

## Features

- Browse 450+ iTerm2 color schemes with live preview
- Filter by dark/light themes or favorites only
- **Dual favorites system**:
  - `favorites.base` — syncs across machines via git
  - `favorites.local` — machine-specific additions/removals (gitignored)
- Install themes directly to iTerm2
- Keyboard-driven navigation

## Setup

1. Clone this repo
2. Clone or have [iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes) somewhere
3. Copy config:
   ```bash
   cp config.example config.local
   ```
4. Edit `config.local` to point to your schemes directory:
   ```bash
   SCHEMES_DIR="/path/to/iTerm2-Color-Schemes/schemes"
   ```

## Usage

```bash
./theme-picker.sh
```

### Controls

| Key | Action |
|-----|--------|
| `n` / `Space` / `Enter` | Next theme |
| `p` | Previous theme |
| `j` | Jump to theme number |
| `s` | Save to **local** favorites (this machine only) |
| `S` | Save to **base** favorites (syncs across machines) |
| `x` | Remove/hide from favorites |
| `u` | Unhide (if hidden locally) |
| `i` | Install theme to iTerm2 |
| `f` | Toggle favorites-only mode |
| `d` | Show dark themes only |
| `L` | Show light themes only |
| `a` | Show all themes |
| `l` | List all favorites |
| `h` | Show help |
| `q` | Quit |

## Favorites System

The dual favorites system lets you:
- **Sync your curated list** across machines via `favorites.base`
- **Customize per-machine** via `favorites.local` without affecting the repo

### How it works

- `favorites.base` — Tracked in git. Your curated theme list.
- `favorites.local` — Gitignored. Machine-specific additions.
  - Add theme names to include them locally
  - Prefix with `-` to hide base themes (e.g., `-Nord`)

### Example

```
# favorites.base (syncs)
Nord
Dracula
Solarized Dark

# favorites.local on machine B (gitignored)
Gruvbox Dark
-Solarized Dark
```

Result on machine B: Nord, Dracula, Gruvbox Dark (Solarized Dark hidden)

When you push, only `favorites.base` goes to the repo. Machine B's removals don't affect other machines.

## Importing Favorites

After cloning on a new machine:

```bash
./import-favorites.sh
```

This installs all your effective favorites into iTerm2.

## Requirements

- macOS with iTerm2
- Ruby (for live preview)
- [iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes) repo
