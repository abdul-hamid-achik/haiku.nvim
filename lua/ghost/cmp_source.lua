-- ghost.nvim/lua/ghost/cmp_source.lua
-- nvim-cmp source integration for ghost.nvim

local M = {}

--- Create a new cmp source instance.
function M.new()
  return setmetatable({}, { __index = M })
end

--- Get the source name.
function M:get_keyword_pattern()
  return [[\k\+]]
end

--- Get debug name.
function M:get_debug_name()
  return "ghost"
end

--- Check if source is available.
function M:is_available()
  local ghost = require("ghost")
  return ghost.is_enabled() and ghost.is_filetype_enabled()
end

--- Get trigger characters.
function M:get_trigger_characters()
  -- Trigger on common code characters
  return { ".", ":", "(", "[", "{", " ", "\n" }
end

--- Complete request from cmp.
---@param params table cmp completion params
---@param callback function callback to call with completion items
function M:complete(params, callback)
  local ghost = require("ghost")
  if not ghost.is_enabled() then
    callback({ items = {} })
    return
  end

  local context_mod = require("ghost.context")
  local api = require("ghost.api")
  local completion = require("ghost.completion")
  local cache = require("ghost.cache")
  local util = require("ghost.util")

  -- Build context
  local ctx = context_mod.build()

  -- Check cache first
  local cache_key = cache.make_key(ctx)
  local cached = cache.get(cache_key)
  if cached then
    local parsed = completion.parse_completion(cached, ctx)
    if parsed then
      util.log("[cmp] Cache hit", vim.log.levels.DEBUG)
      callback({ items = { M.make_item(parsed, ctx) } })
      return
    end
  end

  -- Build prompt
  local prompt = completion.build_prompt(ctx)

  util.log("[cmp] Requesting completion from API", vim.log.levels.DEBUG)

  -- Make streaming API request
  api.stream(prompt, {
    on_complete = function(final_text)
      util.log("[cmp] API response complete", vim.log.levels.DEBUG)

      -- Cache the result
      cache.set(cache_key, final_text)

      -- Parse and return as cmp item
      local parsed = completion.parse_completion(final_text, ctx)
      if parsed then
        callback({ items = { M.make_item(parsed, ctx) } })
      else
        callback({ items = {} })
      end
    end,

    on_error = function(err)
      util.log("[cmp] API error: " .. tostring(err), vim.log.levels.WARN)
      callback({ items = {} })
    end,
  })
end

--- Convert ghost completion to cmp item.
---@param completion table Parsed completion from ghost
---@param ctx table Context
---@return table item cmp completion item
function M.make_item(completion, ctx)
  local cmp = require("cmp")

  -- Get the text to insert
  local text
  if completion.type == "insert" then
    text = completion.text
  else
    -- For edits, use the insert part (cmp can't do deletions)
    text = completion.insert or ""
  end

  -- Create preview label (first line, truncated)
  local first_line = (text or ""):match("^[^\n]*") or ""
  local label = first_line:sub(1, 50)
  if #first_line > 50 then
    label = label .. "..."
  end
  if label == "" then
    label = "[AI completion]"
  end

  -- Add indicator for edit vs insert
  if completion.type == "edit" then
    label = label .. " [edit]"
  end

  return {
    label = label,
    insertText = text,
    kind = cmp.lsp.CompletionItemKind.Snippet,
    detail = "[ghost.nvim]",
    documentation = {
      kind = "markdown",
      value = "```" .. (ctx.filetype or "") .. "\n" .. (text or "") .. "\n```",
    },
  }
end

--- Register ghost as a cmp source.
---@return boolean success Whether registration succeeded
function M.register()
  local has_cmp, cmp = pcall(require, "cmp")
  if not has_cmp then
    return false
  end

  cmp.register_source("ghost", M.new())
  return true
end

return M
