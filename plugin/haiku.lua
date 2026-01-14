-- haiku.nvim/plugin/haiku.lua
-- Plugin initialization, commands, and autoloading

-- Guard against double-loading
if vim.g.loaded_haiku then
  return
end
vim.g.loaded_haiku = true

-- Check Neovim version (requires 0.10+)
if vim.fn.has("nvim-0.10") ~= 1 then
  vim.notify("[haiku.nvim] Requires Neovim 0.10 or higher", vim.log.levels.ERROR)
  return
end

-- Lazy load the main module
local function load_haiku()
  return require("haiku")
end

-- Define user commands

-- :Haiku - Toggle haiku completions
vim.api.nvim_create_user_command("Haiku", function()
  load_haiku().toggle()
  local status = load_haiku().is_enabled() and "enabled" or "disabled"
  vim.notify("[haiku.nvim] " .. status, vim.log.levels.INFO)
end, { desc = "Toggle haiku.nvim completions" })

-- :HaikuEnable - Enable haiku completions
vim.api.nvim_create_user_command("HaikuEnable", function()
  load_haiku().enable()
  vim.notify("[haiku.nvim] enabled", vim.log.levels.INFO)
end, { desc = "Enable haiku.nvim completions" })

-- :HaikuDisable - Disable haiku completions
vim.api.nvim_create_user_command("HaikuDisable", function()
  load_haiku().disable()
  vim.notify("[haiku.nvim] disabled", vim.log.levels.INFO)
end, { desc = "Disable haiku.nvim completions" })

-- :HaikuStatus - Show current status
vim.api.nvim_create_user_command("HaikuStatus", function()
  local ghost = load_haiku()
  local status = ghost.status()
  local cache_stats = require("haiku.cache").stats()

  local cmp_status = "standalone"
  if status.use_cmp then
    cmp_status = "nvim-cmp integration"
  end

  local lines = {
    "haiku.nvim status:",
    "  Enabled: " .. tostring(status.enabled),
    "  Initialized: " .. tostring(status.initialized),
    "  Model: " .. (status.model or "not set"),
    "  API Key: " .. (status.api_key_set and "set" or "NOT SET"),
    "  Mode: " .. cmp_status,
    "  Cache: " .. cache_stats.size .. "/" .. cache_stats.max_size .. " entries",
  }

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end, { desc = "Show haiku.nvim status" })

-- :HaikuClear - Clear the cache
vim.api.nvim_create_user_command("HaikuClear", function()
  require("haiku.cache").clear()
  require("haiku.prediction").clear()
  vim.notify("[haiku.nvim] Cache cleared", vim.log.levels.INFO)
end, { desc = "Clear haiku.nvim cache" })

-- :HaikuDebug - Show debug info
vim.api.nvim_create_user_command("HaikuDebug", function()
  local ghost = load_haiku()
  local cache = require("haiku.cache")
  local prediction = require("haiku.prediction")
  local completion = require("haiku.completion")
  local render = require("haiku.render")

  -- Helper to add multi-line inspect output
  local lines = {}
  local function add(text)
    for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
      table.insert(lines, line)
    end
  end

  add("=== haiku.nvim Debug Info ===")
  add("")
  add("-- Status --")
  add(vim.inspect(ghost.status()))
  add("")
  add("-- Config --")
  add("Model: " .. ghost.config.model)
  add("Debounce: " .. ghost.config.debounce_ms .. "ms")
  add("Idle trigger: " .. ghost.config.idle_trigger_ms .. "ms")
  add("")
  add("-- Cache --")
  add(vim.inspect(cache.stats()))
  add("")
  add("-- Prediction --")
  add(vim.inspect(prediction.stats()))
  add("")
  add("-- Completion State --")
  add(vim.inspect(completion.get_state()))
  add("")
  add("-- Render State --")
  add(vim.inspect(render.get_state()))

  -- Open in a new split with scratch buffer
  vim.cmd("new")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "lua"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
end, { desc = "Show haiku.nvim debug info" })

-- :HaikuTrigger - Manually trigger completion
vim.api.nvim_create_user_command("HaikuTrigger", function()
  if not load_haiku().is_enabled() then
    vim.notify("[haiku.nvim] Not enabled. Run :HaikuEnable first.", vim.log.levels.WARN)
    return
  end
  require("haiku.trigger").trigger_now()
end, { desc = "Manually trigger haiku completion" })

-- :HaikuDebugToggle - Toggle debug logging at runtime
vim.api.nvim_create_user_command("HaikuDebugToggle", function()
  load_haiku().set_debug()
end, { desc = "Toggle haiku.nvim debug logging" })
