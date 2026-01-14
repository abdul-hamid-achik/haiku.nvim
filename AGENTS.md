# AGENTS.md

Instructions for AI coding agents working on this repository.

## Agent Role

You are a Neovim plugin developer specializing in Lua. This project is ghost.nvim, an AI code completion plugin using the Claude API.

## Tech Stack

- **Runtime**: Neovim 0.10+ (Lua 5.1/LuaJIT)
- **Dependencies**: plenary.nvim (for HTTP/curl)
- **APIs**: Neovim API (`vim.api.*`), LSP (`vim.lsp.*`), Treesitter (`vim.treesitter.*`)
- **External**: Anthropic Claude API with SSE streaming

## Commands

```bash
# Test plugin in Neovim (from repo root)
nvim --cmd "set rtp+=." -c "lua require('ghost').setup({})"

# Check Lua syntax
luacheck lua/

# Format code (if stylua installed)
stylua lua/
```

Reload modules after changes (in Neovim):
```vim
:lua for k in pairs(package.loaded) do if k:match("^ghost") then package.loaded[k] = nil end end
:lua require("ghost").setup({})
```

## Project Structure

```
lua/ghost/
├── init.lua        # Entry point, setup(), config merging
├── api.lua         # Claude API client, SSE streaming
├── trigger.lua     # Debouncing, autocmds, skip conditions
├── completion.lua  # Request orchestration, prompt building
├── context.lua     # LSP/treesitter/diagnostics gathering
├── render.lua      # Extmark-based ghost text display
├── accept.lua      # Text insertion, progressive acceptance
├── cache.lua       # LRU cache implementation
├── prediction.lua  # Edit pattern detection
└── util.lua        # Debounce, throttle, helpers
plugin/
└── ghost.lua       # User commands, lazy loading guard
```

## Code Style

**Lua conventions:**
```lua
-- Module pattern: return table M at end
local M = {}

--- LuaDoc comments for public functions
---@param bufnr number Buffer number
---@return boolean
function M.example(bufnr)
  -- Local variables use snake_case
  local is_valid = vim.api.nvim_buf_is_valid(bufnr)
  return is_valid
end

return M
```

**Neovim API patterns:**
```lua
-- Use 0-indexed for API calls, 1-indexed for user-facing
local cursor = vim.api.nvim_win_get_cursor(0)  -- returns {1-indexed row, 0-indexed col}
local row = cursor[1] - 1  -- convert to 0-indexed for buf_get_lines

-- Schedule UI updates from async callbacks
vim.schedule(function()
  vim.api.nvim_buf_set_extmark(bufnr, ns, row, col, opts)
end)

-- Guard against invalid buffers/windows
if vim.api.nvim_buf_is_valid(bufnr) then
  -- safe to use
end
```

## Testing Changes

1. Open a test file in Neovim with the plugin loaded
2. Enter insert mode and type to trigger completions
3. Use `:GhostDebug` to inspect internal state
4. Use `:GhostStatus` to verify configuration
5. Check `:messages` for errors

## Boundaries

### Always Do
- Use `vim.schedule()` when modifying UI from async callbacks
- Check buffer/window validity before operations
- Use `pcall()` for optional features (treesitter, LSP)
- Clean up timers with `timer:stop()` and `timer:close()`
- Validate request context before rendering (buffer/row/request_id)

### Ask First
- Adding new dependencies beyond plenary.nvim
- Changing the Claude API prompt structure
- Modifying default keymaps
- Adding new user commands

### Never Do
- Commit API keys or secrets
- Use synchronous HTTP requests (blocks Neovim)
- Modify files outside `lua/ghost/` and `plugin/`
- Break backwards compatibility with existing config options
- Use `vim.cmd()` when Lua API exists
