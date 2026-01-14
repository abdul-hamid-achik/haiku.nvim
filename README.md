# haiku.nvim

AI-powered code completions for Neovim, powered by Anthropic's Claude Haiku model. Haiku.nvim provides intelligent inline suggestions as you type, similar to GitHub Copilot or Cursor.

> **Note:** This is an independent open-source project, not affiliated with or endorsed by Anthropic. It uses the Anthropic API to provide completions.

## Features

- **nvim-cmp integration** - AI suggestions appear in your completion menu alongside LSP (auto-detected)
- **Standalone mode** - Or use classic inline text when nvim-cmp isn't installed
- **Real-time completions** - Shows suggestions as you type with intelligent debouncing
- **Progressive acceptance** - Accept full completion, next word, or current line only (standalone mode)
- **Edit mode** - Suggests edits (delete + insert) not just insertions
- **Rich context awareness** - Includes LSP symbols, diagnostics, treesitter scope, and recent edits
- **Smart triggering** - Activates on text changes, cursor idle, or manual trigger
- **LRU caching** - Fast repeat completions without API calls
- **Pattern detection** - Detects repetitive editing patterns and predicts next edit locations

## Requirements

- Neovim 0.10+
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- Anthropic API key
- Optional: [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) (for integrated completion menu)
- Optional: LSP client (for symbols and diagnostics)
- Optional: Treesitter (for scope context)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "abdul-hamid-achik/haiku.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("haiku").setup({
      -- your config here (see Configuration below)
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "abdul-hamid-achik/haiku.nvim",
  requires = { "nvim-lua/plenary.nvim" },
  config = function()
    require("haiku").setup({})
  end,
}
```

## Configuration

### API Key Setup

Set your API key via environment variable (recommended):

```bash
export HAIKU_API_KEY="sk-ant-your-key-here"
```

This uses `HAIKU_API_KEY` by default to avoid conflicts with other tools like Claude Code. Falls back to `ANTHROPIC_API_KEY` if `HAIKU_API_KEY` is not set.

Or pass it directly in the configuration (not recommended for security):

```lua
require("haiku").setup({
  api_key = "sk-ant-your-key-here",
})
```

### Full Configuration

All options with their defaults:

```lua
require("haiku").setup({
  -- API settings
  api_key = nil,                              -- Falls back to HAIKU_API_KEY or ANTHROPIC_API_KEY
  model = "claude-haiku-4-5",                 -- Claude Haiku model (alias for latest Haiku 4.5)
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
    haiku_hl = "Comment",                     -- Highlight group for inline text
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

  -- nvim-cmp integration
  cmp = {
    enabled = "auto",                         -- "auto" | true | false
  },

  -- Debug
  debug = false,
})
```

### Minimal Configuration

```lua
require("haiku").setup({})  -- Uses all defaults, API key from env var
```

### Custom Model

```lua
require("haiku").setup({
  model = "claude-sonnet-4-5",  -- Use Sonnet 4.5 for higher quality
  max_tokens = 1024,
})
```

### Pin to Specific Version (Recommended for Production)

```lua
require("haiku").setup({
  -- Use full model ID for consistent behavior in production
  model = "claude-haiku-4-5-20251001",
})
```

### Limit to Specific Filetypes

```lua
require("haiku").setup({
  enabled_ft = { "lua", "python", "javascript", "typescript", "rust", "go" },
})
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:Haiku` | Toggle haiku.nvim on/off |
| `:HaikuEnable` | Enable completions |
| `:HaikuDisable` | Disable completions |
| `:HaikuStatus` | Show current status (enabled, model, cache stats) |
| `:HaikuClear` | Clear the completion cache |
| `:HaikuDebug` | Show debug information |
| `:HaikuTrigger` | Manually trigger a completion |

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
2. After a brief pause (default 300ms), inline text appears showing the suggestion
3. Press `<Tab>` to accept the full completion
4. Or use `<C-Right>` to accept word-by-word
5. Or use `<C-l>` to accept line-by-line
6. Press `<C-]>` to dismiss the suggestion

### Manual Trigger

If you want to trigger a completion without waiting for the debounce:

```vim
:HaikuTrigger
```

Or bind it to a key:

```lua
vim.keymap.set("i", "<C-Space>", "<cmd>HaikuTrigger<cr>", { desc = "Trigger haiku completion" })
```

## Architecture

```
lua/haiku/
├── init.lua              -- Plugin setup and configuration
├── plugin/
│   └── haiku.lua         -- Commands and plugin entry point
└── modules/
    ├── api.lua           -- Claude API client with streaming
    ├── trigger.lua       -- Smart trigger logic with debouncing
    ├── render.lua        -- Inline text display (extmarks)
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
5. **Render** - Shows inline text using Neovim extmarks
6. **Accept** - Inserts accepted text into buffer

## Troubleshooting

### No completions appearing

1. Check that haiku.nvim is enabled: `:HaikuStatus`
2. Verify your API key is set: `echo $HAIKU_API_KEY` (or `$ANTHROPIC_API_KEY`)
3. Check if the filetype is enabled: `:set ft?`
4. Enable debug mode for more info: `:HaikuDebug`

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

Haiku.nvim **automatically integrates with nvim-cmp** when detected. AI suggestions appear directly in your completion menu alongside LSP completions - no configuration needed!

#### Automatic Integration (Recommended)

```lua
-- haiku.nvim setup (cmp integration is automatic)
{
  "abdul-hamid-achik/haiku.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  event = "InsertEnter",
  config = function()
    require("haiku").setup({})  -- cmp.enabled = "auto" by default
  end,
}

-- Add haiku to your cmp sources
require("cmp").setup({
  sources = {
    { name = "nvim_lsp" },
    { name = "haiku" },      -- AI completions appear here with [haiku.nvim] label
    { name = "luasnip" },
    { name = "buffer" },
  },
})
```

Check integration status with `:HaikuStatus` - it will show `Mode: nvim-cmp integration` or `Mode: standalone`.

#### Configuration Options

```lua
require("haiku").setup({
  cmp = {
    enabled = "auto",  -- "auto" (detect cmp), true (force), false (standalone mode)
  },
})
```

#### Standalone Mode (Inline Text)

If you prefer classic inline text instead of cmp integration:

```lua
require("haiku").setup({
  cmp = { enabled = false },  -- Force standalone mode
  keymap = {
    accept = "<Tab>",
    accept_word = "<C-Right>",
    accept_line = "<C-l>",
    dismiss = "<C-]>",
  },
})
```

#### Smart Tab (Standalone Mode)

When using standalone mode with nvim-cmp, use Smart Tab to handle both:

```lua
{
  "abdul-hamid-achik/haiku.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  event = "InsertEnter",
  config = function()
    require("haiku").setup({
      cmp = { enabled = false },  -- Use standalone inline text
      keymap = {
        accept = "",  -- Disable default Tab, we'll handle it manually
        accept_word = "<M-Right>",
        accept_line = "<C-l>",
        dismiss = "<C-]>",
      },
    })

    -- Smart Tab: haiku.nvim → nvim-cmp → luasnip → fallback
    vim.keymap.set("i", "<Tab>", function()
      local haiku_render = require("haiku.render")
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      if haiku_render.has_completion() then
        require("haiku.accept").accept()
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
  end,
}
```

#### Feature Comparison

| Feature | nvim-cmp Mode | Standalone Mode |
|---------|---------------|-----------------|
| AI suggestions in cmp menu | Yes | No |
| Inline text | No | Yes |
| Word-by-word accept | No | Yes |
| Line-by-line accept | No | Yes |
| Suggestion cycling | No | Yes |
| Edit mode diff preview | No | Yes |

## Attribution

This plugin is powered by Anthropic's Claude Haiku model. It is an independent open-source project and is not affiliated with, endorsed by, or sponsored by Anthropic.

## License

MIT
