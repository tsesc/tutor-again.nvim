# tutor-again.nvim

Query-based Vim learning plugin for Neovim. Press `?`, type what you want to do, get the answer instantly with fuzzy search.

## Features

- Fuzzy search across 90+ Vim commands (English & Chinese)
- Two floating windows: query input + live results
- Detail view with mnemonic, description, and related commands
- Persistent search history with deduplication
- Supports zh-TW labels and tags

## Requirements

- Neovim >= 0.9

## Installation

### lazy.nvim

```lua
{
  "jacktse/tutor-again.nvim",
  opts = {},
  keys = { { "?", desc = "tutor-again: open" } },
}
```

## Usage

| Key / Command | Action |
|---|---|
| `?` | Open search window |
| `:TutorAgain` | Open search window |
| `:TutorAgain history` | Open with history view |

### In search window

| Key | Action |
|---|---|
| Type text | Live fuzzy search |
| `<Up>` / `<Down>` | Navigate results |
| `<CR>` | Select result / open detail |
| `<Esc>` | Close |

### In detail view

| Key | Action |
|---|---|
| `q` / `<Esc>` | Close |
| `y` | Copy keys to clipboard |
| `?` | Back to search |

## Configuration

```lua
require("tutor-again").setup({
  keymap = "?",         -- keybind to open (set "" to disable)
  lang = "zh-TW",       -- language for display
  history = {
    max_entries = 500,   -- max history entries
  },
})
```

## Development

```bash
# Run all tests
make test

# Run unit tests only
make test-unit

# Run integration tests only
make test-integration
```

## License

MIT
