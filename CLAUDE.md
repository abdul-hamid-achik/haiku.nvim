# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ghost.nvim is a Neovim plugin providing AI-powered code completions using the Claude API. It displays "ghost text" suggestions as the user types, similar to GitHub Copilot.

## Development

This is a pure Lua Neovim plugin with no build step. To test changes:

```bash
# Open Neovim in the plugin directory
nvim --cmd "set rtp+=." test_file.lua

# Reload the plugin after changes (in Neovim)
:lua package.loaded["ghost"] = nil
:lua package.loaded["ghost.trigger"] = nil  -- repeat for each module
:lua require("ghost").setup({})
```

Manual testing commands:
- `:GhostStatus` - Check plugin state
- `:GhostDebug` - Inspect internal state (cache, render, completion)
- `:GhostTrigger` - Force a completion request

## Architecture

The completion flow follows this pipeline:

```
trigger.lua → context.lua → cache.lua → api.lua → render.lua → accept.lua
    ↓              ↓            ↓           ↓           ↓
 debounce     gather LSP    check LRU   stream SSE  extmarks
 + skip       diagnostics    cache      from Claude  virtual
 conditions   treesitter                             text
```

**Key design patterns:**

- **Request invalidation**: Each completion request gets a unique ID (`completion.lua:30`). Before rendering, the context is validated - if buffer/row changed or a newer request exists, the response is discarded.

- **SSE streaming**: The API module (`api.lua:12-67`) implements a custom SSE parser that handles partial chunks and extracts `content_block_delta` events from Claude's streaming response.

- **Two completion types**: INSERT (pure text insertion) and EDIT (<<<DELETE/<<<INSERT markers for refactoring). The prompt in `completion.lua:137-156` instructs Claude on this format.

- **Progressive acceptance**: Users can accept word-by-word or line-by-line. The render module updates the remaining ghost text in place (`render.lua:247-266`).

## Module Responsibilities

| Module | State | Purpose |
|--------|-------|---------|
| `init.lua` | `M.enabled`, `M.config` | Setup, configuration merging, filetype checks |
| `trigger.lua` | timers, `cancel_fn` | Debouncing, skip conditions, autocmds |
| `completion.lua` | `request_id`, cursor position | Orchestrates requests, builds prompts, parses responses |
| `api.lua` | (stateless) | Claude API client with SSE streaming |
| `context.lua` | (stateless) | Gathers code, LSP symbols, diagnostics, treesitter scope |
| `render.lua` | `completion`, `extmark_id`, `float_win` | Virtual text display via extmarks |
| `accept.lua` | (stateless) | Text insertion, edit application |
| `cache.lua` | LRU cache | Keyed by `before_cursor[-300:] + after_cursor[:100]` |
| `prediction.lua` | recent edits history | Pattern detection for repetitive edits |

## Skip Conditions

Completions are skipped when (`trigger.lua:152-208`):
- Not in insert mode
- Filetype disabled
- Buffer >10K lines
- Popup menu visible (nvim-cmp active)
- Recording macro
- Line has <3 characters
- Cursor in comment/string (via treesitter, if configured)

## API Integration

- Endpoint: `https://api.anthropic.com/v1/messages`
- Auth header: `x-api-key`
- Streaming via `stream: true` and SSE parsing
- Model aliases (e.g., `claude-haiku-4-5`) resolve to latest snapshot
