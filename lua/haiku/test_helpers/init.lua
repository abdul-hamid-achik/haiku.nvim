-- haiku.nvim/lua/haiku/test_helpers/init.lua
-- Test setup and teardown utilities

local M = {}

--- Clear all haiku module caches for fresh test state.
function M.reset_modules()
  for key in pairs(package.loaded) do
    if key:match("^haiku") and not key:match("test_helpers") then
      package.loaded[key] = nil
    end
  end
end

--- Setup haiku for testing with optional config overrides.
---@param opts? table Config overrides
---@return table haiku The haiku module
function M.setup_haiku(opts)
  M.reset_modules()

  opts = opts or {}
  local config = vim.tbl_deep_extend("force", {
    api_key = "test-api-key",
    debug = false,
    debounce_ms = 10,  -- Fast for tests
    idle_trigger_ms = 50,
  }, opts)

  local haiku = require("haiku")
  haiku.setup(config)

  return haiku
end

--- Teardown haiku after tests.
function M.teardown_haiku()
  local ok, haiku = pcall(require, "haiku")
  if ok and haiku.initialized then
    haiku.disable()
  end

  local render_ok, render = pcall(require, "haiku.render")
  if render_ok then
    pcall(render.clear)
  end

  local trigger_ok, trigger = pcall(require, "haiku.trigger")
  if trigger_ok then
    pcall(trigger.cancel)
  end

  M.reset_modules()
end

--- Create a test buffer with content.
---@param lines? string[] Lines to set in buffer
---@param filetype? string Filetype to set
---@return number bufnr The buffer number
function M.create_test_buffer(lines, filetype)
  lines = lines or { "" }
  filetype = filetype or "lua"

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_current_buf(bufnr)
  vim.bo[bufnr].filetype = filetype

  return bufnr
end

--- Delete a test buffer.
---@param bufnr number Buffer number to delete
function M.delete_test_buffer(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

--- Set cursor position in current window.
---@param row number 1-indexed row
---@param col number 0-indexed column
function M.set_cursor(row, col)
  vim.api.nvim_win_set_cursor(0, { row, col })
end

--- Get buffer content as a single string.
---@param bufnr? number Buffer number (default: current)
---@return string content
function M.get_buffer_content(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return table.concat(lines, "\n")
end

--- Wait for a condition to be true.
---@param condition function Function that returns boolean
---@param timeout_ms? number Timeout in milliseconds (default: 1000)
---@return boolean success Whether condition became true
function M.wait_for(condition, timeout_ms)
  timeout_ms = timeout_ms or 1000
  return vim.wait(timeout_ms, condition, 10)
end

return M
