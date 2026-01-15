-- haiku.nvim/lua/haiku/test_helpers/mocks.lua
-- Mock factories for testing

local M = {}

--- Create a mock context object.
---@param overrides? table Fields to override
---@return table context
function M.create_context(overrides)
  local ctx = {
    bufnr = 1,
    filename = "test.lua",
    filepath = "/test/test.lua",
    filetype = "lua",
    row = 1,
    col = 10,
    before_cursor = "local x = ",
    after_cursor = "",
    current_line = "local x = ",
    diagnostics = {},
    treesitter_scope = nil,
    lsp_symbols = {},
    recent_changes = {},
    other_buffers = {},
  }

  if overrides then
    ctx = vim.tbl_deep_extend("force", ctx, overrides)
  end

  return ctx
end

--- Create a mock INSERT completion.
---@param text string The completion text
---@return table completion
function M.create_insert_completion(text)
  return {
    type = "insert",
    text = text,
    raw = text,
  }
end

--- Create a mock EDIT completion.
---@param delete_text string|nil Text to delete
---@param insert_text string|nil Text to insert
---@return table completion
function M.create_edit_completion(delete_text, insert_text)
  local raw_parts = {}
  if delete_text then
    table.insert(raw_parts, "<<<DELETE")
    table.insert(raw_parts, delete_text)
    table.insert(raw_parts, ">>>")
  end
  if insert_text then
    table.insert(raw_parts, "<<<INSERT")
    table.insert(raw_parts, insert_text)
    table.insert(raw_parts, ">>>")
  end

  return {
    type = "edit",
    delete = delete_text,
    insert = insert_text,
    raw = table.concat(raw_parts, "\n"),
  }
end

--- Create a mock SSE chunk (content_block_delta).
---@param text string The text content
---@return string chunk
function M.create_sse_chunk(text)
  local escaped = text:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n')
  return string.format(
    'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"%s"}}',
    escaped
  )
end

--- Create a mock SSE message_start event.
---@return string chunk
function M.create_sse_message_start()
  return 'data: {"type":"message_start","message":{"id":"msg_test","type":"message","role":"assistant","content":[],"model":"claude-haiku-4-5","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":10,"output_tokens":0}}}'
end

--- Create a mock SSE content_block_start event.
---@return string chunk
function M.create_sse_content_block_start()
  return 'data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}'
end

--- Create a mock SSE message_stop event.
---@return string chunk
function M.create_sse_message_stop()
  return 'data: {"type":"message_stop"}'
end

--- Create a mock SSE error event.
---@param message string Error message
---@return string chunk
function M.create_sse_error(message)
  local escaped = message:gsub('"', '\\"')
  return string.format(
    'data: {"type":"error","error":{"type":"api_error","message":"%s"}}',
    escaped
  )
end

--- Create a mock diagnostic.
---@param overrides? table Fields to override
---@return table diagnostic
function M.create_diagnostic(overrides)
  local diag = {
    lnum = 5,
    col = 10,
    severity = vim.diagnostic.severity.ERROR,
    message = "undefined variable 'foo'",
    source = "lua_ls",
  }

  if overrides then
    diag = vim.tbl_deep_extend("force", diag, overrides)
  end

  return diag
end

--- Create a mock LSP symbol.
---@param name string Symbol name
---@param kind? string Symbol kind (default: "Function")
---@return table symbol
function M.create_lsp_symbol(name, kind)
  return {
    name = name,
    kind = kind or "Function",
    detail = nil,
    deprecated = false,
  }
end

--- Create a mock config object for testing.
---@param overrides? table Config overrides
---@return table config
function M.create_config(overrides)
  local config = {
    api_key = "test-api-key",
    model = "claude-haiku-4-5",
    max_tokens = 512,
    debounce_ms = 10,
    min_chars = 3,
    idle_trigger_ms = 50,
    trigger = {
      on_insert = true,
      on_idle = true,
      after_accept = true,
      on_new_line = true,
      in_comments = false,
    },
    context = {
      lines_before = 100,
      lines_after = 50,
      max_file_size = 100000,
      include_diagnostics = true,
      include_lsp_symbols = true,
      include_treesitter = true,
      include_recent_changes = true,
      other_buffers = { enabled = false },
    },
    display = {
      haiku_hl = "Comment",
      delete_hl = "DiffDelete",
      change_hl = "DiffChange",
      priority = 1000,
      max_lines = 20,
    },
    limits = {
      max_buffer_lines = 10000,
      edit_search_radius = 20,
      max_lsp_symbols = 20,
      max_symbol_depth = 2,
      max_diagnostics = 5,
    },
    cache = {
      max_size = 50,
      ttl_seconds = 300,
    },
    keymap = {
      accept = "<Tab>",
      accept_word = "<C-Right>",
      accept_line = "<C-l>",
      next = "<M-]>",
      prev = "<M-[>",
      dismiss = "<C-]>",
    },
    prediction = {
      enabled = true,
      jump_on_accept = false,
    },
    debug = false,
  }

  if overrides then
    config = vim.tbl_deep_extend("force", config, overrides)
  end

  return config
end

return M
