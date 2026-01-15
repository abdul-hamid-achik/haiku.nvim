-- haiku.nvim/lua/haiku/core.lua
-- Pure functions extracted for testability
-- No Neovim API dependencies, no requires to other haiku modules

local M = {}

-----------------------------------------------------------
-- SSE Parser (from api.lua)
-----------------------------------------------------------

--- Create an SSE (Server-Sent Events) parser.
--- Handles partial chunks and extracts text deltas from Claude's streaming response.
---@param callbacks table { on_text = function, on_complete = function, on_error = function }
---@return function parser The parser function to feed chunks to
function M.create_sse_parser(callbacks)
  local buffer = ""

  return function(chunk)
    if not chunk then
      return
    end

    buffer = buffer .. chunk

    -- Process complete lines
    while true do
      local newline_pos = buffer:find("\n")
      if not newline_pos then
        break
      end

      local line = buffer:sub(1, newline_pos - 1)
      buffer = buffer:sub(newline_pos + 1)

      -- Remove carriage return if present (CRLF -> LF)
      line = line:gsub("\r$", "")

      -- Parse SSE data lines
      if line:match("^data: ") then
        local json_str = line:sub(7)

        -- Skip [DONE] marker
        if json_str == "[DONE]" then
          if callbacks.on_complete then
            callbacks.on_complete()
          end
          return
        end

        -- Parse JSON
        local ok, data = pcall(vim.json.decode, json_str)
        if ok and data then
          -- Handle different event types
          if data.type == "content_block_delta" then
            if data.delta and data.delta.type == "text_delta" and data.delta.text then
              if callbacks.on_text then
                callbacks.on_text(data.delta.text)
              end
            end
          elseif data.type == "message_stop" then
            if callbacks.on_complete then
              callbacks.on_complete()
            end
          elseif data.type == "error" then
            local err_msg = "API error"
            if data.error and data.error.message then
              err_msg = data.error.message
            end
            if callbacks.on_error then
              callbacks.on_error(err_msg)
            end
          end
          -- Ignore other event types: message_start, content_block_start, content_block_stop, message_delta
        end
      end
    end
  end
end

-----------------------------------------------------------
-- Text Matching (from accept.lua)
-----------------------------------------------------------

--- Find exact multi-line match in buffer lines.
---@param lines table Buffer lines (array of strings)
---@param search_lines table Lines to find (array of strings)
---@param start_idx number Start index (1-indexed)
---@param end_idx number End index (1-indexed)
---@return number|nil match_idx 1-indexed position where match starts, or nil
function M.find_exact_match(lines, search_lines, start_idx, end_idx)
  for i = start_idx, end_idx do
    local all_match = true
    for j, search_line in ipairs(search_lines) do
      local buffer_line = lines[i + j - 1]
      if buffer_line == nil or buffer_line ~= search_line then
        all_match = false
        break
      end
    end
    if all_match then
      return i
    end
  end
  return nil
end

--- Find fuzzy match (whitespace-tolerant) in buffer lines.
---@param lines table Buffer lines (array of strings)
---@param search_lines table Lines to find (array of strings)
---@param start_idx number Start index (1-indexed)
---@param end_idx number End index (1-indexed)
---@return number|nil match_idx 1-indexed position where match starts, or nil
function M.find_fuzzy_match(lines, search_lines, start_idx, end_idx)
  local first_line_trimmed = search_lines[1]:match("^%s*(.-)%s*$")

  for i = start_idx, end_idx do
    local line_trimmed = (lines[i] or ""):match("^%s*(.-)%s*$")
    if line_trimmed == first_line_trimmed then
      if #search_lines == 1 then
        return i
      else
        -- Multi-line: check if rest matches with whitespace tolerance
        local all_match = true
        for j = 2, #search_lines do
          local buf_trimmed = (lines[i + j - 1] or ""):match("^%s*(.-)%s*$")
          local search_trimmed = search_lines[j]:match("^%s*(.-)%s*$")
          if buf_trimmed ~= search_trimmed then
            all_match = false
            break
          end
        end
        if all_match then
          return i
        end
      end
    end
  end
  return nil
end

-----------------------------------------------------------
-- Word/Line Boundary Detection (from accept.lua)
-----------------------------------------------------------

--- Find the next word boundary in text.
--- Returns the word (including leading whitespace) and remaining text.
---@param text string The text to search
---@return string|nil word The word found (nil if none)
---@return string remaining The remaining text after the word
function M.find_word_boundary(text)
  if not text or text == "" then
    return nil, ""
  end

  -- Match: word characters, or non-space characters, or leading whitespace + first word
  local word = text:match("^(%s*[%w_]+)")      -- Leading whitespace + identifier
    or text:match("^(%s*[^%s]+)")              -- Leading whitespace + any non-space token
    or text:match("^(%s+)")                    -- Just whitespace (for indent)

  if not word then
    return nil, text
  end

  local remaining = text:sub(#word + 1)
  return word, remaining
end

--- Find the first line in text.
--- Returns the line and remaining text (after newline).
---@param text string The text to search
---@return string|nil line The first line (nil if empty)
---@return string remaining The remaining text after the line
function M.find_line_boundary(text)
  if not text or text == "" then
    return nil, ""
  end

  local newline_pos = text:find("\n")
  if newline_pos then
    local line = text:sub(1, newline_pos - 1)
    local remaining = text:sub(newline_pos + 1)
    return line, remaining
  else
    return text, ""
  end
end

-----------------------------------------------------------
-- Completion Parsing (re-exported from completion.lua)
-----------------------------------------------------------

--- Clean unwanted artifacts from completion text.
---@param text string The text to clean
---@return string cleaned The cleaned text
function M.clean_completion_text(text)
  if not text then
    return ""
  end

  return text
    -- Remove cursor markers
    :gsub("<|CURSOR|>", "")
    -- Remove markdown code fences (```lang at start, ``` at end)
    :gsub("^```%w*\n?", "")
    :gsub("\n?```%s*$", "")
    -- Remove trailing newline
    :gsub("\n$", "")
end

--- Parse EDIT markers using line-based approach.
---@param text string The text to parse
---@return string|nil delete_content Content to delete
---@return string|nil insert_content Content to insert
function M.parse_edit_markers(text)
  local lines = vim.split(text, "\n", { plain = true })
  local delete_lines = {}
  local insert_lines = {}
  local current_section = nil  -- nil, "delete", or "insert"

  for _, line in ipairs(lines) do
    if line == "<<<DELETE" then
      current_section = "delete"
    elseif line == "<<<INSERT" then
      current_section = "insert"
    elseif line == ">>>" then
      current_section = nil
    elseif current_section == "delete" then
      table.insert(delete_lines, line)
    elseif current_section == "insert" then
      table.insert(insert_lines, line)
    end
  end

  local delete_content = #delete_lines > 0 and table.concat(delete_lines, "\n") or nil
  local insert_content = #insert_lines > 0 and table.concat(insert_lines, "\n") or nil

  return delete_content, insert_content
end

--- Parse completion text, detecting if it's INSERT or EDIT.
---@param text string The completion text
---@return table|nil completion { type = "insert"|"edit", text?, delete?, insert?, raw }
function M.parse_completion(text)
  if not text or text == "" then
    return nil
  end

  -- Check for edit markers
  if text:find("<<<DELETE") or text:find("<<<INSERT") then
    local delete_match, insert_match = M.parse_edit_markers(text)

    if delete_match or insert_match then
      delete_match = M.clean_completion_text(delete_match)
      insert_match = M.clean_completion_text(insert_match)

      return {
        type = "edit",
        delete = delete_match,
        insert = insert_match,
        raw = text,
      }
    end
  end

  -- Pure insert: clean up the text
  local cleaned = M.clean_completion_text(text)
    :gsub("^%s*", "")  -- Also trim leading whitespace for inserts

  if cleaned == "" then
    return nil
  end

  return {
    type = "insert",
    text = cleaned,
    raw = text,
  }
end

return M
