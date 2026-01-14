# ghost.nvim

AI-powered code completions for Neovim using Claude. Ghost.nvim provides intelligent "ghost text" suggestions as you type, similar to GitHub Copilot or Cursor.

## Features

- **Real-time completions** - Shows suggestions as you type with intelligent debouncing
- **Progressive acceptance** - Accept full completion, next word, or current line only
- **Edit mode** - Suggests edits (delete + insert) not just insertions
- **Rich context awareness** - Includes LSP symbols, diagnostics, treesitter scope, and recent edits
- **Smart triggering** - Activates on text changes, cursor idle, or manual trigger
- **LRU caching** - Fast repeat completions without API calls
- **Pattern detection** - Detects repetitive editing patterns and predicts next edit locations

## Requirements

- Neovim 0.10+
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- Anthropic API key
- Optional: LSP client (for symbols and diagnostics)
- Optional: Treesitter (for scope context)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "abdul-hamid-achik/ghost.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("ghost").setup({
      -- your config here (see Configuration below)
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "abdul-hamid-achik/ghost.nvim",
  requires = { "nvim-lua/plenary.nvim" },
  config = function()
    require("ghost").setup({})
  end,
}
```

## Configuration

### API Key Setup

Set your Anthropic API key via environment variable:

```bash
export ANTHROPIC_API_KEY="sk-ant-your-key-here"
```

Or pass it directly in the configuration (not recommended for security):

```lua
require("ghost").setup({
  api_key = "sk-ant-your-key-here",
})
```

### Full Configuration

All options with their defaults:

```lua
require("ghost").setup({
  -- API settings
  api_key = nil,                              -- Falls back to ANTHROPIC_API_KEY env var
  model = "claude-haiku-4-5",                 -- Claude model (alias for latest Haiku 4.5)
  max_tokens = 512,                           -- Max tokens per completion

  -- Timing
  debounce_ms = 300,                          -- Wait after typing stops (ms)
  min_chars = 3,                              -- Minimum characters before triggering
  idle_trigger_ms = 800,                      -- Trigger after idle time (ms)

  -- Trigger conditions
  trigger = {
    on_insert = true,                         -- Trigger in insert mode
    on_idle = true,                           -- Trigger after idle time
    after_accept = true,                      -- Trigger after accepting completion
    on_new_line = true,                       -- Trigger when creating new line
    in_comments = false,                      -- Disable in comments
  },

  -- Context gathering
  context = {
    lines_before = 100,                       -- Lines of context before cursor
    lines_after = 50,                         -- Lines of context after cursor
    max_file_size = 100000,                   -- Skip files larger than this (bytes)
    include_diagnostics = true,               -- Include LSP errors/warnings
    include_lsp_symbols = true,               -- Include document symbols
    include_treesitter = true,                -- Include treesitter scope
    include_recent_changes = true,            -- Track recent edits
    other_buffers = false,                    -- Include other open buffers
  },

  -- Keymaps
  keymap = {
    accept = "<Tab>",                         -- Accept full completion
    accept_word = "<C-Right>",                -- Accept next word only
    accept_line = "<C-l>",                    -- Accept current line only
    next = "<M-]>",                           -- Cycle to next suggestion
    prev = "<M-[>",                           -- Cycle to previous
    dismiss = "<C-]>",                        -- Dismiss completion
  },

  -- Display settings
  display = {
    ghost_hl = "Comment",                     -- Highlight group for ghost text
    delete_hl = "DiffDelete",                 -- Highlight for deleted text
    change_hl = "DiffChange",                 -- Highlight for changed text
    priority = 1000,                          -- Extmark priority
    max_lines = 20,                           -- Max lines to display
  },

  -- Filetypes
  enabled_ft = { "*" },                       -- Enabled filetypes ("*" for all)
  disabled_ft = {                             -- Disabled filetypes
    "TelescopePrompt", "NvimTree", "neo-tree",
    "lazy", "mason", "help", "qf", "fugitive",
    "git", "gitcommit", "DressingInput", "DressingSelect"
  },

  -- Advanced features
  prediction = {
    enabled = true,                           -- Enable next-cursor prediction
    jump_on_accept = false,                   -- Auto-jump to next edit location
  },
  patterns = {
    detect_repetitive = true,                 -- Detect repetitive edits
    max_pattern_edits = 10,                   -- Max locations to suggest
  },

  -- Debug
  debug = false,
})
```

### Minimal Configuration

```lua
require("ghost").setup({})  -- Uses all defaults, API key from env var
```

### Custom Model

```lua
require("ghost").setup({
  model = "claude-sonnet-4-5",  -- Use Sonnet 4.5 for higher quality
  max_tokens = 1024,
})
```

### Pin to Specific Version (Recommended for Production)

```lua
require("ghost").setup({
  -- Use full model ID for consistent behavior in production
  model = "claude-haiku-4-5-20251001",
})
```

### Limit to Specific Filetypes

```lua
require("ghost").setup({
  enabled_ft = { "lua", "python", "javascript", "typescript", "rust", "go" },
})
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:Ghost` | Toggle ghost.nvim on/off |
| `:GhostEnable` | Enable completions |
| `:GhostDisable` | Disable completions |
| `:GhostStatus` | Show current status (enabled, model, cache stats) |
| `:GhostClear` | Clear the completion cache |
| `:GhostDebug` | Show debug information |
| `:GhostTrigger` | Manually trigger a completion |

### Keymaps (Insert Mode)

| Key | Action |
|-----|--------|
| `<Tab>` | Accept full completion |
| `<C-Right>` | Accept next word only |
| `<C-l>` | Accept current line only |
| `<C-]>` | Dismiss completion |
| `<Esc>` | Dismiss and exit insert mode |
| `<M-]>` | Next suggestion |
| `<M-[>` | Previous suggestion |

### Workflow

1. Start typing code in insert mode
2. After a brief pause (default 300ms), ghost text appears showing the suggestion
3. Press `<Tab>` to accept the full completion
4. Or use `<C-Right>` to accept word-by-word
5. Or use `<C-l>` to accept line-by-line
6. Press `<C-]>` to dismiss the suggestion

### Manual Trigger

If you want to trigger a completion without waiting for the debounce:

```vim
:GhostTrigger
```

Or bind it to a key:

```lua
vim.keymap.set("i", "<C-Space>", "<cmd>GhostTrigger<cr>", { desc = "Trigger ghost completion" })
```

## Architecture

```
lua/ghost/
├── init.lua              -- Plugin setup and configuration
├── plugin/
│   └── ghost.lua         -- Commands and plugin entry point
└── modules/
    ├── api.lua           -- Claude API client with streaming
    ├── trigger.lua       -- Smart trigger logic with debouncing
    ├── render.lua        -- Ghost text display (extmarks)
    ├── accept.lua        -- Progressive acceptance
    ├── completion.lua    -- Core completion engine
    ├── context.lua       -- Context gathering (LSP, treesitter)
    ├── cache.lua         -- LRU cache
    ├── prediction.lua    -- Pattern detection and prediction
    └── util.lua          -- Utility functions
```

### Completion Flow

1. **Trigger** - Monitors text changes with debouncing
2. **Context** - Builds rich context (code, LSP, diagnostics, treesitter)
3. **Cache** - Checks if completion is already cached
4. **API** - Streams completion from Claude using SSE
5. **Render** - Shows ghost text using Neovim extmarks
6. **Accept** - Inserts accepted text into buffer

## Troubleshooting

### No completions appearing

1. Check that ghost.nvim is enabled: `:GhostStatus`
2. Verify your API key is set: `echo $ANTHROPIC_API_KEY`
3. Check if the filetype is enabled: `:set ft?`
4. Enable debug mode for more info: `:GhostDebug`

### Completions are slow

- Try using `claude-haiku-4-5` (the default) for faster responses
- Increase `debounce_ms` to reduce API calls
- Reduce `context.lines_before` and `context.lines_after`

### High API costs

- Increase `debounce_ms` (e.g., 500ms)
- Disable `trigger.on_idle`
- Use the Haiku model (cheapest)
- Limit to specific filetypes with `enabled_ft`

### Integration with nvim-cmp

Ghost.nvim's default `<Tab>` key conflicts with nvim-cmp. Here are two solutions:

#### Option 1: Use Different Keys (Simple)

```lua
{
  "abdul-hamid-achik/ghost.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  event = "InsertEnter",
  config = function()
    require("ghost").setup({
      keymap = {
        accept = "<C-y>",           -- Accept full completion (traditional "yes")
        accept_word = "<M-Right>",  -- Accept next word (Alt+Right)
        accept_line = "<C-l>",      -- Accept current line
        dismiss = "<C-]>",          -- Dismiss suggestion
      },
    })
  end,
}
```

#### Option 2: Smart Tab (Best DX)

Tab intelligently handles ghost.nvim, nvim-cmp, and LuaSnip:

```lua
{
  "abdul-hamid-achik/ghost.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  event = "InsertEnter",
  config = function()
    require("ghost").setup({
      keymap = {
        accept = "",  -- Disable default Tab, we'll handle it manually
        accept_word = "<M-Right>",
        accept_line = "<C-l>",
        dismiss = "<C-]>",
      },
    })

    -- Smart Tab: ghost.nvim → nvim-cmp → luasnip → fallback
    vim.keymap.set("i", "<Tab>", function()
      local ghost_render = require("ghost.render")
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      if ghost_render.has_completion() then
        require("ghost.accept").accept()
      elseif cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_locally_jumpable() then
        luasnip.expand_or_jump()
      else
        vim.api.nvim_feedkeys(
          vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", false
        )
      end
    end, { silent = true, desc = "Smart Tab" })

    -- Also add Ctrl+Y as explicit accept (works even when cmp menu is open)
    vim.keymap.set("i", "<C-y>", function()
      if require("ghost.render").has_completion() then
        require("ghost.accept").accept()
      end
    end, { silent = true, desc = "Accept ghost completion" })
  end,
}
```

#### Recommended Keymaps Summary

| Key | Action | Notes |
|-----|--------|-------|
| `<Tab>` | Smart accept | Ghost → cmp → luasnip → indent |
| `<C-y>` | Force accept ghost | Works even with cmp menu open |
| `<M-Right>` | Accept word | Alt+Right, progressive |
| `<C-l>` | Accept line | Line by line |
| `<C-]>` | Dismiss | Close ghost suggestion |

## License

MIT
