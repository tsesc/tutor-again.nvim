# tutor-again.nvim Design

**Date**: 2026-03-04
**Status**: Approved

## Positioning

Install Neovim, then install tutor-again — all subsequent Vim learning stays in the terminal.

A query-based Vim learning plugin: press `?`, describe what you want to do, get the answer instantly. With history and optional LLM mode.

## Architecture

```
tutor-again.nvim
├── Local mode (default) ── Built-in command database + fuzzy search
├── LLM mode (optional) ── Claude / OpenAI / Ollama with websearch
└── History system ──────── Persistent query history, searchable
```

## Two Modes

### Local Mode (`?`)

- Built-in 300+ Vim command database
- Fuzzy search (Chinese + English)
- Offline, zero latency

### LLM Mode (`<C-l>` to toggle)

- Natural language Vim questions
- Websearch for latest plugin info
- Multi-provider: Claude / OpenAI / Ollama
- Answers tagged with source (local / LLM / web)

## UX Flow

### Query Window

```
Normal mode: press ?
       ↓
┌─────────────────────────────────────────┐
│  tutor-again              [Local] [LLM] │
├─────────────────────────────────────────┤
│ > _                            <C-l> 切換│
├─────────────────────────────────────────┤
│  Recent queries                          │
│  如何刪除整行                   10m ago  │
│  跳到檔案開頭                   1h ago   │
│  複製整個段落                   2h ago   │
└─────────────────────────────────────────┘
```

### Detail View

```
┌─────────────────────────────────────────┐
│  dw — Delete to next word start         │
├─────────────────────────────────────────┤
│  Keys:     d (delete) + w (word)        │
│  Mnemonic: d=delete, w=word             │
│                                         │
│  Related:                               │
│  • de   delete to word end              │
│  • diw  delete inner word               │
│  • daw  delete a word (with spaces)     │
│                                         │
│  [q] close  [y] copy  [?] back          │
└─────────────────────────────────────────┘
```

### LLM Mode

```
┌─────────────────────────────────────────┐
│  tutor-again              [Local] [LLM] │
├─────────────────────────────────────────┤
│ > 我想在多行同時插入相同的文字怎麼做？    │
├─────────────────────────────────────────┤
│  LLM response:                          │
│  1. Visual Block: Ctrl-v select → I     │
│  2. :norm I<text> batch insert          │
│  3. Macro: qa → edit → q → @a replay   │
│                                         │
│  Source: Claude API                     │
│  [q] close  [y] copy  [s] save to db   │
└─────────────────────────────────────────┘
```

## Keybindings

| Key | Action |
|-----|--------|
| `?` | Open query window (local mode) |
| `<C-l>` | Toggle Local / LLM mode |
| `<CR>` | Select result / submit LLM query |
| `<C-y>` | Copy command to clipboard |
| `<C-s>` | Save LLM answer to local DB |
| `q` / `<Esc>` | Close |

## Ex Commands

| Command | Action |
|---------|--------|
| `:TutorAgain` | Open query window |
| `:TutorAgain history` | Show history only |
| `:TutorAgain categories` | Browse by category |
| `:TutorAgain setup` | Configure LLM provider |

## Configuration

```lua
require("tutor-again").setup({
  keymap = "?",
  lang = "zh-TW",

  llm = {
    provider = "claude",  -- "claude" | "openai" | "ollama"
    model = "claude-sonnet-4-20250514",
    api_key_env = "ANTHROPIC_API_KEY",
    websearch = true,
  },

  history = {
    max_entries = 500,
    path = vim.fn.stdpath("data") .. "/tutor-again/history.json",
  },
})
```

## Local Database Structure

```lua
{
  keys = "dw",
  name = "Delete to next word",
  name_zh = "刪除到下一個字",
  tags = { "delete", "word", "刪除", "字", "operator" },
  category = "operators.delete",
  mnemonic = "d=delete, w=word",
  description = "Delete from cursor to the start of the next word",
  related = { "de", "diw", "daw", "D" },
}
```

### Categories

- `movement` — hjkl, w/b/e, f/t, gg/G, 0/$, %
- `operators` — d, c, y, >, <, =
- `text_objects` — iw, aw, i", a(, it
- `visual` — v, V, Ctrl-v
- `insert` — i, a, o, I, A, O
- `search` — /, ?, *, #, n/N
- `registers` — ", @, Ctrl-r
- `marks` — m, ', `
- `macros` — q, @
- `windows` — Ctrl-w series
- `tabs_buffers` — :bn, :bp, gt, gT

## File Structure

```
tutor-again.nvim/
├── lua/
│   └── tutor-again/
│       ├── init.lua          -- setup() entry
│       ├── ui.lua            -- floating window UI
│       ├── search.lua        -- fuzzy search engine
│       ├── history.lua       -- history management
│       ├── llm/
│       │   ├── init.lua      -- LLM mode entry
│       │   ├── claude.lua    -- Claude provider
│       │   ├── openai.lua    -- OpenAI provider
│       │   └── ollama.lua    -- Ollama provider
│       └── db/
│           ├── init.lua      -- database loader
│           ├── movement.lua
│           ├── operators.lua
│           ├── text_objects.lua
│           ├── visual.lua
│           ├── insert.lua
│           ├── search_cmds.lua
│           ├── registers.lua
│           ├── marks.lua
│           ├── macros.lua
│           └── windows.lua
└── README.md
```

## Phasing

### Phase 1 — MVP (Local mode only)

1. `?` opens floating window + fuzzy search
2. Local database: movement + operators + text_objects (~100 entries)
3. Detail view with key breakdown and related commands
4. Persistent history

### Phase 2 — LLM Integration

1. LLM mode with `<C-l>` toggle
2. Claude / OpenAI / Ollama providers
3. Websearch capability
4. Save LLM answers to local DB

### Phase 3 — Polish

1. Complete database (all categories, 300+ entries)
2. Category browsing
3. User-contributed entries
4. Detect actual keybinds (LazyVim overrides)

## Differentiation

| Feature | :Tutor | VimTeacher | hardtime | **tutor-again** |
|---------|--------|------------|----------|-----------------|
| Query-based | ✗ | ✗ | ✗ | ✓ |
| Chinese support | ✗ | ✗ | ✗ | ✓ |
| History | ✗ | ✗ | ✗ | ✓ |
| LLM integration | ✗ | ✗ | ✗ | ✓ |
| Offline | ✓ | ✓ | ✓ | ✓ |
| Fuzzy search | ✗ | ✗ | ✗ | ✓ |
