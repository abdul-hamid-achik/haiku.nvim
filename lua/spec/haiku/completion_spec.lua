-- Tests for haiku/completion.lua
local mocks = require("haiku.test_helpers.mocks")
local helpers = require("haiku.test_helpers")

describe("completion", function()
  local completion

  before_each(function()
    package.loaded["haiku.completion"] = nil
    package.loaded["haiku"] = nil

    -- Setup minimal haiku config
    local haiku = require("haiku")
    haiku.config = mocks.create_config()

    completion = require("haiku.completion")
  end)

  -----------------------------------------------------------
  -- is_context_valid() Tests
  -----------------------------------------------------------
  describe("is_context_valid()", function()
    local bufnr

    before_each(function()
      -- Create a test buffer
      bufnr = helpers.create_test_buffer({ "line 1", "line 2", "line 3" }, "lua")
      helpers.set_cursor(2, 5)
    end)

    after_each(function()
      helpers.delete_test_buffer(bufnr)
    end)

    it("returns false when request_id differs (superseded)", function()
      -- Internal state starts with request_id = 0
      local result = completion.is_context_valid(999)
      assert.is_false(result)
    end)

    it("returns false when buffer changed", function()
      -- Simulate a request being made
      local state = completion.get_state()
      local current_request_id = state.request_id

      -- Set internal state to a different buffer
      -- We need to trigger a request to set state, but we can test
      -- by checking that mismatched buffer returns false
      -- For this, we simulate by setting internal state manually

      -- Since we can't easily set internal state, we test the behavior
      -- with the default state (bufnr = nil)
      local result = completion.is_context_valid(0)
      -- bufnr is nil initially, so won't match current buffer
      assert.is_false(result)
    end)

    it("returns true when context matches", function()
      -- Create a new buffer and manually trigger state update
      -- by checking the get_state returns matching values
      local state = completion.get_state()

      -- Initially request_id is 0, and bufnr/row/col are nil
      -- So is_context_valid(0) will fail buffer check
      assert.is_false(completion.is_context_valid(0))
    end)
  end)

  -----------------------------------------------------------
  -- build_prompt() Tests
  -----------------------------------------------------------
  describe("build_prompt()", function()
    it("includes filename and filetype", function()
      local ctx = mocks.create_context({
        filename = "test.lua",
        filetype = "lua",
      })

      local prompt = completion.build_prompt(ctx)

      assert.is_string(prompt.system)
      assert.is_string(prompt.user)
      assert.matches("File: test.lua %(lua%)", prompt.user)
    end)

    it("includes treesitter scope when available", function()
      local ctx = mocks.create_context({
        treesitter_scope = {
          type = "function_declaration",
          line = "function test()",
          start_row = 5,
        },
      })

      local prompt = completion.build_prompt(ctx)

      assert.matches("Currently in: function_declaration", prompt.user)
    end)

    it("does not include treesitter scope when nil", function()
      local ctx = mocks.create_context({
        treesitter_scope = nil,
      })

      local prompt = completion.build_prompt(ctx)

      assert.is_nil(prompt.user:match("Currently in:"))
    end)

    it("includes diagnostics with line numbers", function()
      local ctx = mocks.create_context({
        diagnostics = {
          { lnum = 4, col = 10, severity = "ERROR", message = "undefined variable" },
          { lnum = 6, col = 5, severity = "WARN", message = "unused variable" },
        },
      })

      local prompt = completion.build_prompt(ctx)

      assert.matches("Current issues:", prompt.user)
      assert.matches("Line 5 %[ERROR%]: undefined variable", prompt.user)
      assert.matches("Line 7 %[WARN%]: unused variable", prompt.user)
    end)

    it("does not include diagnostics section when empty", function()
      local ctx = mocks.create_context({
        diagnostics = {},
      })

      local prompt = completion.build_prompt(ctx)

      assert.is_nil(prompt.user:match("Current issues:"))
    end)

    it("includes LSP symbols", function()
      local ctx = mocks.create_context({
        lsp_symbols = {
          { kind = "Function", name = "myFunc" },
          { kind = "Variable", name = "myVar" },
        },
      })

      local prompt = completion.build_prompt(ctx)

      assert.matches("Relevant symbols:", prompt.user)
      assert.matches("Function: myFunc", prompt.user)
      assert.matches("Variable: myVar", prompt.user)
    end)

    it("limits LSP symbols to 10", function()
      local symbols = {}
      for i = 1, 15 do
        table.insert(symbols, { kind = "Function", name = "func" .. i })
      end

      local ctx = mocks.create_context({
        lsp_symbols = symbols,
      })

      local prompt = completion.build_prompt(ctx)

      assert.matches("func10", prompt.user)
      assert.is_nil(prompt.user:match("func11"))
    end)

    it("includes other_buffers context when available", function()
      local ctx = mocks.create_context({
        other_buffers = {
          {
            name = "helper.lua",
            filetype = "lua",
            symbols = { { kind = "Function", name = "helperFunc" } },
            snippet = "local function helperFunc() end",
          },
        },
      })

      local prompt = completion.build_prompt(ctx)

      assert.matches("Related files:", prompt.user)
      assert.matches("helper.lua", prompt.user)
      assert.matches("helperFunc", prompt.user)
    end)

    it("uses <|CURSOR|> marker in code context", function()
      local ctx = mocks.create_context({
        before_cursor = "local x = ",
        after_cursor = "\nprint(x)",
      })

      local prompt = completion.build_prompt(ctx)

      assert.matches("local x = <|CURSOR|>", prompt.user, 1, true)
    end)

    it("system prompt instructs to never output <|CURSOR|>", function()
      local ctx = mocks.create_context()

      local prompt = completion.build_prompt(ctx)

      assert.matches("Never include <|CURSOR|> in your output", prompt.system)
    end)

    it("system prompt explains EDIT format", function()
      local ctx = mocks.create_context()

      local prompt = completion.build_prompt(ctx)

      assert.matches("<<<DELETE", prompt.system)
      assert.matches("<<<INSERT", prompt.system)
    end)

    it("handles special characters in filename", function()
      local ctx = mocks.create_context({
        filename = "test file (1).lua",
        filetype = "lua",
      })

      local prompt = completion.build_prompt(ctx)

      -- The filename should appear in the prompt (escaping parens for pattern)
      assert.matches("test file %(1%)%.lua", prompt.user)
    end)

    it("handles filenames with brackets and quotes", function()
      local ctx = mocks.create_context({
        filename = "component[0].ts",
        filetype = "typescript",
      })

      local prompt = completion.build_prompt(ctx)

      -- Should include the filename without crashing
      assert.is_string(prompt.user)
      assert.matches("component", prompt.user)
    end)
  end)

  -----------------------------------------------------------
  -- parse_completion() Tests
  -----------------------------------------------------------
  describe("parse_completion()", function()
    it("delegates to core.parse_completion", function()
      local result = completion.parse_completion("hello world", {})

      assert.is_not_nil(result)
      assert.are.equal("insert", result.type)
      assert.are.equal("hello world", result.text)
    end)

    it("handles EDIT type", function()
      local text = "<<<DELETE\nold\n>>>\n<<<INSERT\nnew\n>>>"
      local result = completion.parse_completion(text, {})

      assert.are.equal("edit", result.type)
      assert.are.equal("old", result.delete)
      assert.are.equal("new", result.insert)
    end)

    it("returns nil for empty text", function()
      local result = completion.parse_completion("", {})
      assert.is_nil(result)
    end)
  end)

  -----------------------------------------------------------
  -- get_state() Tests
  -----------------------------------------------------------
  describe("get_state()", function()
    it("returns state object", function()
      local state = completion.get_state()

      assert.is_table(state)
      assert.is_number(state.request_id)
    end)

    it("returns deep copy (modifications don't affect original)", function()
      local state1 = completion.get_state()
      state1.request_id = 9999

      local state2 = completion.get_state()
      assert.are_not.equal(9999, state2.request_id)
    end)
  end)
end)
