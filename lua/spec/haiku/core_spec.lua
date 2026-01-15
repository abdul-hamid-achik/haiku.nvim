-- Tests for haiku/core.lua
local mocks = require("haiku.test_helpers.mocks")

describe("core", function()
  local core

  before_each(function()
    package.loaded["haiku.core"] = nil
    core = require("haiku.core")
  end)

  -----------------------------------------------------------
  -- SSE Parser Tests
  -----------------------------------------------------------
  describe("create_sse_parser()", function()
    it("extracts text from content_block_delta events", function()
      local received_text = {}
      local parser = core.create_sse_parser({
        on_text = function(text)
          table.insert(received_text, text)
        end,
      })

      parser('data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}\n')

      assert.are.equal(1, #received_text)
      assert.are.equal("Hello", received_text[1])
    end)

    it("handles multiple chunks", function()
      local received_text = {}
      local parser = core.create_sse_parser({
        on_text = function(text)
          table.insert(received_text, text)
        end,
      })

      parser('data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}\n')
      parser('data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" World"}}\n')

      assert.are.equal(2, #received_text)
      assert.are.equal("Hello", received_text[1])
      assert.are.equal(" World", received_text[2])
    end)

    it("calls on_complete on message_stop", function()
      local completed = false
      local parser = core.create_sse_parser({
        on_complete = function()
          completed = true
        end,
      })

      parser('data: {"type":"message_stop"}\n')

      assert.is_true(completed)
    end)

    it("calls on_complete on [DONE] marker", function()
      local completed = false
      local parser = core.create_sse_parser({
        on_complete = function()
          completed = true
        end,
      })

      parser('data: [DONE]\n')

      assert.is_true(completed)
    end)

    it("calls on_error on error event", function()
      local error_msg = nil
      local parser = core.create_sse_parser({
        on_error = function(err)
          error_msg = err
        end,
      })

      parser('data: {"type":"error","error":{"type":"api_error","message":"Rate limit exceeded"}}\n')

      assert.are.equal("Rate limit exceeded", error_msg)
    end)

    it("handles partial chunks (buffering)", function()
      local received_text = {}
      local parser = core.create_sse_parser({
        on_text = function(text)
          table.insert(received_text, text)
        end,
      })

      -- Send partial data
      parser('data: {"type":"content_block_delta","index":0,')
      assert.are.equal(0, #received_text) -- Nothing yet

      -- Complete the line
      parser('"delta":{"type":"text_delta","text":"Hello"}}\n')
      assert.are.equal(1, #received_text)
      assert.are.equal("Hello", received_text[1])
    end)

    it("handles CRLF line endings", function()
      local received_text = {}
      local parser = core.create_sse_parser({
        on_text = function(text)
          table.insert(received_text, text)
        end,
      })

      parser('data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}\r\n')

      assert.are.equal(1, #received_text)
      assert.are.equal("Hello", received_text[1])
    end)

    it("ignores non-data lines", function()
      local received_text = {}
      local parser = core.create_sse_parser({
        on_text = function(text)
          table.insert(received_text, text)
        end,
      })

      parser('event: message_start\n')
      parser(': comment line\n')
      parser('\n')
      parser('data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}\n')

      assert.are.equal(1, #received_text)
    end)

    it("ignores message_start and other event types", function()
      local received_text = {}
      local parser = core.create_sse_parser({
        on_text = function(text)
          table.insert(received_text, text)
        end,
      })

      parser('data: {"type":"message_start","message":{"id":"msg_test"}}\n')
      parser('data: {"type":"content_block_start","index":0}\n')
      parser('data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}\n')

      assert.are.equal(1, #received_text)
      assert.are.equal("Hello", received_text[1])
    end)

    it("handles malformed JSON gracefully", function()
      local text_received = false
      local error_received = false
      local parser = core.create_sse_parser({
        on_text = function() text_received = true end,
        on_error = function() error_received = true end,
      })

      -- Malformed JSON should not crash, just be ignored
      assert.has_no.errors(function()
        parser('data: {invalid json}\n')
        parser('data: {"incomplete\n')
        parser('data: not json at all\n')
      end)

      -- Should not have triggered any callbacks
      assert.is_false(text_received)
      assert.is_false(error_received)
    end)
  end)

  -----------------------------------------------------------
  -- Text Matching Tests
  -----------------------------------------------------------
  describe("find_exact_match()", function()
    it("finds single-line match", function()
      local lines = { "line 1", "line 2", "line 3" }
      local search = { "line 2" }

      local result = core.find_exact_match(lines, search, 1, 3)

      assert.are.equal(2, result)
    end)

    it("finds multi-line match", function()
      local lines = { "a", "b", "c", "d" }
      local search = { "b", "c" }

      local result = core.find_exact_match(lines, search, 1, 3)

      assert.are.equal(2, result)
    end)

    it("returns nil when no match", function()
      local lines = { "a", "b", "c" }
      local search = { "x" }

      local result = core.find_exact_match(lines, search, 1, 3)

      assert.is_nil(result)
    end)

    it("respects search bounds", function()
      local lines = { "a", "target", "b", "target" }
      local search = { "target" }

      -- Only search in range 3-4
      local result = core.find_exact_match(lines, search, 3, 4)

      assert.are.equal(4, result)
    end)

    it("requires exact match (no whitespace tolerance)", function()
      local lines = { "  line 1", "line 1" }
      local search = { "line 1" }

      local result = core.find_exact_match(lines, search, 1, 2)

      assert.are.equal(2, result) -- Second line, not first
    end)
  end)

  describe("find_fuzzy_match()", function()
    it("matches with whitespace tolerance", function()
      local lines = { "  line 1  ", "other" }
      local search = { "line 1" }

      local result = core.find_fuzzy_match(lines, search, 1, 2)

      assert.are.equal(1, result)
    end)

    it("matches multi-line with whitespace tolerance", function()
      local lines = { "  a  ", "  b  ", "c" }
      local search = { "a", "b" }

      local result = core.find_fuzzy_match(lines, search, 1, 2)

      assert.are.equal(1, result)
    end)

    it("returns nil when no match", function()
      local lines = { "a", "b" }
      local search = { "x" }

      local result = core.find_fuzzy_match(lines, search, 1, 2)

      assert.is_nil(result)
    end)
  end)

  -----------------------------------------------------------
  -- Word/Line Boundary Tests
  -----------------------------------------------------------
  describe("find_word_boundary()", function()
    it("finds identifier word", function()
      local word, remaining = core.find_word_boundary("hello world")

      assert.are.equal("hello", word)
      assert.are.equal(" world", remaining)
    end)

    it("includes leading whitespace", function()
      local word, remaining = core.find_word_boundary("  hello world")

      assert.are.equal("  hello", word)
      assert.are.equal(" world", remaining)
    end)

    it("handles punctuation as word", function()
      local word, remaining = core.find_word_boundary("++ rest")

      assert.are.equal("++", word)
      assert.are.equal(" rest", remaining)
    end)

    it("handles whitespace only", function()
      local word, remaining = core.find_word_boundary("   ")

      assert.are.equal("   ", word)
      assert.are.equal("", remaining)
    end)

    it("returns nil for empty string", function()
      local word, remaining = core.find_word_boundary("")

      assert.is_nil(word)
      assert.are.equal("", remaining)
    end)
  end)

  describe("find_line_boundary()", function()
    it("finds first line", function()
      local line, remaining = core.find_line_boundary("line1\nline2\nline3")

      assert.are.equal("line1", line)
      assert.are.equal("line2\nline3", remaining)
    end)

    it("handles single line (no newline)", function()
      local line, remaining = core.find_line_boundary("only line")

      assert.are.equal("only line", line)
      assert.are.equal("", remaining)
    end)

    it("returns nil for empty string", function()
      local line, remaining = core.find_line_boundary("")

      assert.is_nil(line)
      assert.are.equal("", remaining)
    end)

    it("handles empty first line", function()
      local line, remaining = core.find_line_boundary("\nsecond")

      assert.are.equal("", line)
      assert.are.equal("second", remaining)
    end)
  end)

  -----------------------------------------------------------
  -- Completion Parsing Tests
  -----------------------------------------------------------
  describe("clean_completion_text()", function()
    it("removes cursor markers", function()
      local result = core.clean_completion_text("hello<|CURSOR|>world")

      assert.are.equal("helloworld", result)
    end)

    it("removes markdown code fences", function()
      local result = core.clean_completion_text("```lua\ncode here\n```")

      assert.are.equal("code here", result)
    end)

    it("removes trailing newline", function()
      local result = core.clean_completion_text("hello\n")

      assert.are.equal("hello", result)
    end)

    it("handles nil input", function()
      local result = core.clean_completion_text(nil)

      assert.are.equal("", result)
    end)
  end)

  describe("parse_edit_markers()", function()
    it("parses DELETE section", function()
      local delete, insert = core.parse_edit_markers("<<<DELETE\nold code\n>>>")

      assert.are.equal("old code", delete)
      assert.is_nil(insert)
    end)

    it("parses INSERT section", function()
      local delete, insert = core.parse_edit_markers("<<<INSERT\nnew code\n>>>")

      assert.is_nil(delete)
      assert.are.equal("new code", insert)
    end)

    it("parses both DELETE and INSERT", function()
      local text = "<<<DELETE\nold\n>>>\n<<<INSERT\nnew\n>>>"
      local delete, insert = core.parse_edit_markers(text)

      assert.are.equal("old", delete)
      assert.are.equal("new", insert)
    end)

    it("handles multi-line content", function()
      local text = "<<<DELETE\nline1\nline2\n>>>"
      local delete, insert = core.parse_edit_markers(text)

      assert.are.equal("line1\nline2", delete)
    end)

    it("handles >>> in content (edge case)", function()
      -- Content with >>> should not break parsing
      local text = "<<<INSERT\nif x > 3 then\n>>>"
      local delete, insert = core.parse_edit_markers(text)

      assert.are.equal("if x > 3 then", insert)
    end)

    it("handles <<<DELETE appearing in content", function()
      -- <<<DELETE as literal text inside a DELETE block
      local text = "<<<DELETE\nif x <<<DELETE then\n>>>"
      local delete, insert = core.parse_edit_markers(text)

      assert.are.equal("if x <<<DELETE then", delete)
      assert.is_nil(insert)
    end)

    it("handles <<<INSERT appearing in content", function()
      -- <<<INSERT as literal text inside an INSERT block
      local text = "<<<INSERT\nprint('<<<INSERT')\n>>>"
      local delete, insert = core.parse_edit_markers(text)

      assert.is_nil(delete)
      assert.are.equal("print('<<<INSERT')", insert)
    end)

    it("handles >>>INSERT appearing in DELETE content", function()
      -- Nested marker-like text should not break parsing
      local text = "<<<DELETE\nif >>>INSERT then\n>>>"
      local delete, insert = core.parse_edit_markers(text)

      assert.are.equal("if >>>INSERT then", delete)
      assert.is_nil(insert)
    end)
  end)

  describe("parse_completion()", function()
    it("returns nil for empty text", function()
      local result = core.parse_completion("")
      assert.is_nil(result)

      result = core.parse_completion(nil)
      assert.is_nil(result)
    end)

    it("detects INSERT type for plain text", function()
      local result = core.parse_completion("hello world")

      assert.are.equal("insert", result.type)
      assert.are.equal("hello world", result.text)
    end)

    it("detects EDIT type with DELETE markers", function()
      local text = "<<<DELETE\nold\n>>>\n<<<INSERT\nnew\n>>>"
      local result = core.parse_completion(text)

      assert.are.equal("edit", result.type)
      assert.are.equal("old", result.delete)
      assert.are.equal("new", result.insert)
    end)

    it("strips markdown code fences from INSERT", function()
      local result = core.parse_completion("```lua\ncode\n```")

      assert.are.equal("insert", result.type)
      assert.are.equal("code", result.text)
    end)

    it("removes cursor markers", function()
      local result = core.parse_completion("hello<|CURSOR|>")

      assert.are.equal("insert", result.type)
      assert.are.equal("hello", result.text)
    end)

    it("returns nil for whitespace-only after cleaning", function()
      local result = core.parse_completion("   \n  ")

      assert.is_nil(result)
    end)

    it("preserves raw text", function()
      local raw = "```lua\ncode\n```"
      local result = core.parse_completion(raw)

      assert.are.equal(raw, result.raw)
    end)

    it("handles Unicode in completion text", function()
      local result = core.parse_completion("const emoji = '🎉'")

      assert.are.equal("insert", result.type)
      assert.are.equal("const emoji = '🎉'", result.text)
    end)

    it("handles multi-byte Unicode characters", function()
      local result = core.parse_completion("日本語テスト")

      assert.are.equal("insert", result.type)
      assert.are.equal("日本語テスト", result.text)
    end)
  end)
end)
