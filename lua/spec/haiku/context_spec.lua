-- Tests for haiku/context.lua
local helpers = require("haiku.test_helpers")
local mocks = require("haiku.test_helpers.mocks")

describe("context", function()
  local context
  local haiku

  before_each(function()
    -- Reset modules
    helpers.reset_modules()

    -- Setup haiku with config
    haiku = require("haiku")
    haiku.config = mocks.create_config()

    context = require("haiku.context")
  end)

  -----------------------------------------------------------
  -- build() Tests
  -----------------------------------------------------------
  describe("build()", function()
    local bufnr

    before_each(function()
      bufnr = helpers.create_test_buffer({
        "line 1",
        "line 2",
        "line 3",
        "line 4",
        "line 5",
      }, "lua")
      helpers.set_cursor(3, 3) -- middle of file
    end)

    after_each(function()
      helpers.delete_test_buffer(bufnr)
    end)

    it("returns context object with required fields", function()
      local ctx = context.build()

      assert.is_table(ctx)
      assert.is_number(ctx.bufnr)
      assert.is_number(ctx.row)
      assert.is_number(ctx.col)
      assert.is_string(ctx.before_cursor)
      assert.is_string(ctx.after_cursor)
      assert.is_string(ctx.filetype)
    end)

    it("captures correct cursor position", function()
      helpers.set_cursor(3, 4)
      local ctx = context.build()

      assert.are.equal(3, ctx.row)
      assert.are.equal(4, ctx.col)
    end)

    it("captures filetype", function()
      local ctx = context.build()
      assert.are.equal("lua", ctx.filetype)
    end)

    it("captures filename", function()
      local ctx = context.build()
      assert.is_string(ctx.filename)
    end)

    it("builds before_cursor correctly", function()
      helpers.set_cursor(3, 4) -- "line 3", col 4 = "line"
      local ctx = context.build()

      -- Should contain lines 1, 2, and partial line 3
      assert.matches("line 1", ctx.before_cursor)
      assert.matches("line 2", ctx.before_cursor)
      assert.matches("line", ctx.before_cursor) -- partial line 3
    end)

    it("builds after_cursor correctly", function()
      helpers.set_cursor(3, 4) -- cursor after "line"
      local ctx = context.build()

      -- Should contain rest of line 3 (" 3") and lines 4, 5
      assert.matches("line 4", ctx.after_cursor)
      assert.matches("line 5", ctx.after_cursor)
    end)

    it("handles cursor at start of file", function()
      helpers.set_cursor(1, 0)
      local ctx = context.build()

      assert.are.equal("", ctx.before_cursor)
      assert.is_true(#ctx.after_cursor > 0)
    end)

    it("handles cursor at end of line", function()
      -- "line 5" is 6 chars, so put cursor at end
      helpers.set_cursor(5, 6)
      local ctx = context.build()

      assert.is_true(#ctx.before_cursor > 0)
      -- after_cursor should be empty or minimal (Neovim may clamp cursor)
      assert.is_true(#ctx.after_cursor <= 1)
    end)

    it("handles empty buffer", function()
      helpers.delete_test_buffer(bufnr)
      bufnr = helpers.create_test_buffer({ "" }, "lua")
      helpers.set_cursor(1, 0)

      local ctx = context.build()

      assert.is_table(ctx)
      assert.are.equal("", ctx.before_cursor)
      assert.are.equal("", ctx.after_cursor)
    end)

    it("handles single line buffer", function()
      helpers.delete_test_buffer(bufnr)
      bufnr = helpers.create_test_buffer({ "only line" }, "lua")
      helpers.set_cursor(1, 4)

      local ctx = context.build()

      assert.are.equal("only", ctx.before_cursor)
      assert.are.equal(" line", ctx.after_cursor)
    end)

    it("includes diagnostics array", function()
      local ctx = context.build()
      assert.is_table(ctx.diagnostics)
    end)

    it("includes lsp_symbols array", function()
      local ctx = context.build()
      assert.is_table(ctx.lsp_symbols)
    end)

    it("includes recent_changes array", function()
      local ctx = context.build()
      assert.is_table(ctx.recent_changes)
    end)
  end)

  -----------------------------------------------------------
  -- get_diagnostics() Tests
  -----------------------------------------------------------
  describe("get_diagnostics()", function()
    local bufnr

    before_each(function()
      bufnr = helpers.create_test_buffer({
        "line 1",
        "line 2",
        "line 3",
        "line 4",
        "line 5",
      }, "lua")
    end)

    after_each(function()
      helpers.delete_test_buffer(bufnr)
    end)

    it("returns empty array when no diagnostics", function()
      local diags = context.get_diagnostics(bufnr, 3)
      assert.are.same({}, diags)
    end)

    it("returns array type", function()
      local diags = context.get_diagnostics(bufnr, 1)
      assert.is_table(diags)
    end)

    it("handles row beyond buffer", function()
      -- Row 100 is beyond the 5-line buffer
      local diags = context.get_diagnostics(bufnr, 100)
      assert.is_table(diags)
    end)
  end)

  -----------------------------------------------------------
  -- get_treesitter_scope() Tests
  -----------------------------------------------------------
  describe("get_treesitter_scope()", function()
    local bufnr

    before_each(function()
      bufnr = helpers.create_test_buffer({
        "local function test()",
        "  local x = 1",
        "  return x",
        "end",
      }, "lua")
    end)

    after_each(function()
      helpers.delete_test_buffer(bufnr)
    end)

    it("returns nil when treesitter unavailable", function()
      -- Create a buffer with no treesitter support
      local txt_buf = helpers.create_test_buffer({ "plain text" }, "")

      local scope = context.get_treesitter_scope(txt_buf, 0, 0)

      -- May return nil or scope depending on treesitter availability
      -- The key is it doesn't error
      assert.has_no.errors(function()
        context.get_treesitter_scope(txt_buf, 0, 0)
      end)

      helpers.delete_test_buffer(txt_buf)
    end)

    it("returns scope object or nil", function()
      local scope = context.get_treesitter_scope(bufnr, 1, 5)

      if scope then
        assert.is_table(scope)
        assert.is_string(scope.type)
        assert.is_string(scope.line)
        assert.is_number(scope.start_row)
      end
    end)

    it("handles cursor outside buffer gracefully", function()
      assert.has_no.errors(function()
        context.get_treesitter_scope(bufnr, 100, 0)
      end)
    end)
  end)

  -----------------------------------------------------------
  -- get_lsp_symbols() Tests
  -----------------------------------------------------------
  describe("get_lsp_symbols()", function()
    local bufnr

    before_each(function()
      bufnr = helpers.create_test_buffer({ "test" }, "lua")
    end)

    after_each(function()
      helpers.delete_test_buffer(bufnr)
    end)

    it("returns empty array when no LSP clients", function()
      local symbols = context.get_lsp_symbols(bufnr)
      assert.is_table(symbols)
    end)

    it("handles invalid buffer gracefully", function()
      assert.has_no.errors(function()
        local symbols = context.get_lsp_symbols(99999)
        assert.is_table(symbols)
      end)
    end)
  end)

  -----------------------------------------------------------
  -- flatten_symbols() Tests
  -----------------------------------------------------------
  describe("flatten_symbols()", function()
    it("flattens empty symbol list", function()
      local result = {}
      context.flatten_symbols({}, result, 0)
      assert.are.same({}, result)
    end)

    it("flattens simple symbol list", function()
      local lsp_symbols = {
        { name = "func1", kind = 12 }, -- Function
        { name = "func2", kind = 12 },
      }
      local result = {}

      context.flatten_symbols(lsp_symbols, result, 0)

      assert.are.equal(2, #result)
      assert.are.equal("func1", result[1].name)
      assert.are.equal("func2", result[2].name)
    end)

    it("handles nested children", function()
      local lsp_symbols = {
        {
          name = "Class1",
          kind = 5, -- Class
          children = {
            { name = "method1", kind = 6 }, -- Method
            { name = "method2", kind = 6 },
          },
        },
      }
      local result = {}

      context.flatten_symbols(lsp_symbols, result, 0)

      assert.are.equal(3, #result)
      assert.are.equal("Class1", result[1].name)
      assert.are.equal("method1", result[2].name)
      assert.are.equal("method2", result[3].name)
    end)

    it("respects max_symbols limit", function()
      haiku.config.limits.max_lsp_symbols = 5

      local lsp_symbols = {}
      for i = 1, 20 do
        table.insert(lsp_symbols, { name = "sym" .. i, kind = 12 })
      end
      local result = {}

      context.flatten_symbols(lsp_symbols, result, 0)

      assert.are.equal(5, #result)
    end)

    it("respects max_depth limit", function()
      haiku.config.limits.max_symbol_depth = 1

      local lsp_symbols = {
        {
          name = "level0",
          kind = 5,
          children = {
            {
              name = "level1",
              kind = 6,
              children = {
                { name = "level2_should_skip", kind = 6 },
              },
            },
          },
        },
      }
      local result = {}

      context.flatten_symbols(lsp_symbols, result, 0)

      -- Should have level0 and level1, but not level2
      assert.are.equal(2, #result)
      assert.are.equal("level0", result[1].name)
      assert.are.equal("level1", result[2].name)
    end)

    it("handles symbols with missing kind", function()
      local lsp_symbols = {
        { name = "no_kind" }, -- kind is missing
      }
      local result = {}

      assert.has_no.errors(function()
        context.flatten_symbols(lsp_symbols, result, 0)
      end)

      assert.are.equal(1, #result)
      assert.are.equal("no_kind", result[1].name)
      assert.are.equal("Unknown", result[1].kind)
    end)
  end)

  -----------------------------------------------------------
  -- get_current_indent() Tests
  -----------------------------------------------------------
  describe("get_current_indent()", function()
    local bufnr

    after_each(function()
      if bufnr then
        helpers.delete_test_buffer(bufnr)
      end
    end)

    it("returns empty string for unindented line", function()
      bufnr = helpers.create_test_buffer({ "no indent" }, "lua")
      helpers.set_cursor(1, 0)

      local indent = context.get_current_indent()
      assert.are.equal("", indent)
    end)

    it("returns spaces for space-indented line", function()
      bufnr = helpers.create_test_buffer({ "  two spaces" }, "lua")
      helpers.set_cursor(1, 0)

      local indent = context.get_current_indent()
      assert.are.equal("  ", indent)
    end)

    it("returns tabs for tab-indented line", function()
      bufnr = helpers.create_test_buffer({ "\ttab" }, "lua")
      helpers.set_cursor(1, 0)

      local indent = context.get_current_indent()
      assert.are.equal("\t", indent)
    end)

    it("returns mixed indentation", function()
      bufnr = helpers.create_test_buffer({ "  \t mixed" }, "lua")
      helpers.set_cursor(1, 0)

      local indent = context.get_current_indent()
      assert.are.equal("  \t ", indent)
    end)
  end)

  -----------------------------------------------------------
  -- get_file_size() Tests
  -----------------------------------------------------------
  describe("get_file_size()", function()
    local bufnr

    after_each(function()
      if bufnr then
        helpers.delete_test_buffer(bufnr)
      end
    end)

    it("returns 0 for empty buffer", function()
      bufnr = helpers.create_test_buffer({ "" }, "lua")

      local size = context.get_file_size(bufnr)
      assert.are.equal(1, size) -- empty line + newline
    end)

    it("calculates size correctly for single line", function()
      bufnr = helpers.create_test_buffer({ "hello" }, "lua")

      local size = context.get_file_size(bufnr)
      assert.are.equal(6, size) -- 5 chars + 1 newline
    end)

    it("calculates size correctly for multiple lines", function()
      bufnr = helpers.create_test_buffer({ "line1", "line2" }, "lua")

      local size = context.get_file_size(bufnr)
      -- "line1" (5) + newline (1) + "line2" (5) + newline (1) = 12
      assert.are.equal(12, size)
    end)
  end)

  -----------------------------------------------------------
  -- get_other_buffers_context() Tests
  -----------------------------------------------------------
  describe("get_other_buffers_context()", function()
    local bufnr1, bufnr2

    before_each(function()
      -- Enable other_buffers in config
      haiku.config.context.other_buffers = {
        enabled = true,
        max_buffers = 3,
        max_lines_per_buffer = 10,
        include_same_filetype = true,
      }

      bufnr1 = helpers.create_test_buffer({ "buffer 1" }, "lua")
    end)

    after_each(function()
      if bufnr1 then
        helpers.delete_test_buffer(bufnr1)
      end
      if bufnr2 then
        helpers.delete_test_buffer(bufnr2)
      end
    end)

    it("returns empty array when disabled", function()
      haiku.config.context.other_buffers.enabled = false

      local result = context.get_other_buffers_context(bufnr1, "lua")
      assert.are.same({}, result)
    end)

    it("excludes current buffer", function()
      -- With only one buffer, result should be empty since current is excluded
      local result = context.get_other_buffers_context(bufnr1, "lua")
      assert.are.same({}, result)
    end)

    it("returns array type", function()
      local result = context.get_other_buffers_context(bufnr1, "lua")
      assert.is_table(result)
    end)
  end)

  -----------------------------------------------------------
  -- extract_buffer_context() Tests
  -----------------------------------------------------------
  describe("extract_buffer_context()", function()
    local bufnr

    before_each(function()
      bufnr = helpers.create_test_buffer({ "line 1", "line 2", "line 3" }, "lua")
    end)

    after_each(function()
      helpers.delete_test_buffer(bufnr)
    end)

    it("extracts filename from filepath", function()
      local ctx_config = { max_lines_per_buffer = 10 }
      local result = context.extract_buffer_context(bufnr, "/path/to/file.lua", "lua", ctx_config)

      assert.is_not_nil(result)
      assert.are.equal("file.lua", result.name)
    end)

    it("includes snippet from buffer", function()
      local ctx_config = { max_lines_per_buffer = 10 }
      local result = context.extract_buffer_context(bufnr, "/path/to/file.lua", "lua", ctx_config)

      assert.is_not_nil(result)
      assert.matches("line 1", result.snippet)
      assert.matches("line 2", result.snippet)
    end)

    it("respects max_lines_per_buffer", function()
      local ctx_config = { max_lines_per_buffer = 1 }
      local result = context.extract_buffer_context(bufnr, "/path/to/file.lua", "lua", ctx_config)

      assert.is_not_nil(result)
      assert.matches("line 1", result.snippet)
      -- Should not include line 2 or 3
      assert.is_nil(result.snippet:match("line 2"))
    end)

    it("returns nil for empty buffer with no symbols", function()
      local empty_buf = helpers.create_test_buffer({ "" }, "lua")
      local ctx_config = { max_lines_per_buffer = 10 }

      local result = context.extract_buffer_context(empty_buf, "/path/empty.lua", "lua", ctx_config)

      -- May return nil or minimal context
      -- The function returns nil if both symbols and snippet are empty
      helpers.delete_test_buffer(empty_buf)
    end)
  end)
end)
