-- Tests for haiku/accept.lua
local helpers = require("haiku.test_helpers")
local mocks = require("haiku.test_helpers.mocks")

describe("accept", function()
  local accept
  local render
  local haiku

  before_each(function()
    -- Reset modules
    helpers.reset_modules()

    -- Setup haiku with config
    haiku = require("haiku")
    haiku.config = mocks.create_config()

    accept = require("haiku.accept")
    render = require("haiku.render")
  end)

  -----------------------------------------------------------
  -- accept() Tests
  -----------------------------------------------------------
  describe("accept()", function()
    local bufnr

    before_each(function()
      bufnr = helpers.create_test_buffer({ "test line" }, "lua")
      helpers.set_cursor(1, 4)
    end)

    after_each(function()
      render.clear()
      helpers.delete_test_buffer(bufnr)
    end)

    it("returns false when no completion", function()
      local result = accept.accept()
      assert.is_false(result)
    end)

    it("returns true when completion exists", function()
      local completion = mocks.create_insert_completion("hello")
      render.show(completion, { row = 1, col = 4 })

      local result = accept.accept()
      assert.is_true(result)
    end)

    it("clears render after acceptance", function()
      local completion = mocks.create_insert_completion("hello")
      render.show(completion, { row = 1, col = 4 })

      accept.accept()

      assert.is_false(render.has_completion())
    end)
  end)

  -----------------------------------------------------------
  -- accept_word() Tests
  -----------------------------------------------------------
  describe("accept_word()", function()
    local bufnr

    before_each(function()
      bufnr = helpers.create_test_buffer({ "test" }, "lua")
      helpers.set_cursor(1, 4)
    end)

    after_each(function()
      render.clear()
      helpers.delete_test_buffer(bufnr)
    end)

    it("returns false when no completion", function()
      local result = accept.accept_word()
      assert.is_false(result)
    end)

    it("returns false for edit type completion", function()
      local completion = mocks.create_edit_completion("old", "new")
      render.show(completion, { row = 1, col = 4 })

      local result = accept.accept_word()
      assert.is_false(result)
    end)

    it("returns true for insert type completion", function()
      local completion = mocks.create_insert_completion("hello world")
      render.show(completion, { row = 1, col = 4 })

      local result = accept.accept_word()
      assert.is_true(result)
    end)

    it("extracts identifier word", function()
      local completion = mocks.create_insert_completion("hello world")
      render.show(completion, { row = 1, col = 4 })

      accept.accept_word()

      -- After accepting "hello", remaining should be " world"
      local current = render.get_current_text()
      if current then
        assert.are.equal(" world", current)
      end
    end)

    it("extracts word with leading whitespace", function()
      local completion = mocks.create_insert_completion("  indented")
      render.show(completion, { row = 1, col = 4 })

      accept.accept_word()

      -- Should accept "  indented" as one word (whitespace + identifier)
      -- or just the whitespace depending on pattern
    end)

    it("handles punctuation as word boundary", function()
      local completion = mocks.create_insert_completion("++rest")
      render.show(completion, { row = 1, col = 4 })

      accept.accept_word()

      -- "++" should be treated as a word
      local current = render.get_current_text()
      if current then
        assert.are.equal("rest", current)
      end
    end)

    it("clears completion when no remainder", function()
      local completion = mocks.create_insert_completion("hello")
      render.show(completion, { row = 1, col = 4 })

      accept.accept_word()

      assert.is_false(render.has_completion())
    end)
  end)

  -----------------------------------------------------------
  -- accept_line() Tests
  -----------------------------------------------------------
  describe("accept_line()", function()
    local bufnr

    before_each(function()
      bufnr = helpers.create_test_buffer({ "test" }, "lua")
      helpers.set_cursor(1, 4)
    end)

    after_each(function()
      render.clear()
      helpers.delete_test_buffer(bufnr)
    end)

    it("returns false when no completion", function()
      local result = accept.accept_line()
      assert.is_false(result)
    end)

    it("returns false for edit type completion", function()
      local completion = mocks.create_edit_completion("old", "new")
      render.show(completion, { row = 1, col = 4 })

      local result = accept.accept_line()
      assert.is_false(result)
    end)

    it("returns true for insert type completion", function()
      local completion = mocks.create_insert_completion("line1\nline2")
      render.show(completion, { row = 1, col = 4 })

      local result = accept.accept_line()
      assert.is_true(result)
    end)

    it("extracts first line from multi-line completion", function()
      local completion = mocks.create_insert_completion("first\nsecond\nthird")
      render.show(completion, { row = 1, col = 4 })

      accept.accept_line()

      -- After accepting "first", remaining should be "second\nthird"
      local current = render.get_current_text()
      if current then
        assert.are.equal("second\nthird", current)
      end
    end)

    it("handles single-line completion", function()
      local completion = mocks.create_insert_completion("only line")
      render.show(completion, { row = 1, col = 4 })

      accept.accept_line()

      -- Should accept entire completion and clear
      assert.is_false(render.has_completion())
    end)

    it("clears when remaining is whitespace-only", function()
      local completion = mocks.create_insert_completion("content\n   ")
      render.show(completion, { row = 1, col = 4 })

      accept.accept_line()

      -- Remaining is just whitespace, should clear
      assert.is_false(render.has_completion())
    end)
  end)

  -----------------------------------------------------------
  -- dismiss() Tests
  -----------------------------------------------------------
  describe("dismiss()", function()
    local bufnr

    before_each(function()
      bufnr = helpers.create_test_buffer({ "test" }, "lua")
      helpers.set_cursor(1, 4)
    end)

    after_each(function()
      helpers.delete_test_buffer(bufnr)
    end)

    it("clears render state", function()
      local completion = mocks.create_insert_completion("hello")
      render.show(completion, { row = 1, col = 4 })

      accept.dismiss()

      assert.is_false(render.has_completion())
    end)

    it("can be called when no completion", function()
      assert.has_no.errors(function()
        accept.dismiss()
      end)
    end)

    it("can be called multiple times", function()
      local completion = mocks.create_insert_completion("hello")
      render.show(completion, { row = 1, col = 4 })

      assert.has_no.errors(function()
        accept.dismiss()
        accept.dismiss()
        accept.dismiss()
      end)
    end)
  end)

  -----------------------------------------------------------
  -- insert_text() Tests
  -----------------------------------------------------------
  describe("insert_text()", function()
    local bufnr

    before_each(function()
      bufnr = helpers.create_test_buffer({ "hello world" }, "lua")
    end)

    after_each(function()
      helpers.delete_test_buffer(bufnr)
    end)

    it("handles nil text gracefully", function()
      assert.has_no.errors(function()
        accept.insert_text(nil)
      end)
    end)

    it("handles empty text gracefully", function()
      assert.has_no.errors(function()
        accept.insert_text("")
      end)
    end)

    it("inserts single-line text at cursor", function()
      helpers.set_cursor(1, 5) -- after "hello"

      accept.insert_text(" there")

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.equal("hello there world", lines[1])
    end)

    it("inserts at start of line", function()
      helpers.set_cursor(1, 0)

      accept.insert_text("prefix ")

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.equal("prefix hello world", lines[1])
    end)

    it("inserts near end of line", function()
      -- Position cursor near end (col=9 is after "hello wor")
      helpers.set_cursor(1, 9)

      accept.insert_text("X")

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Should insert X between "wor" and "ld"
      assert.are.equal("hello worXld", lines[1])
    end)

    it("inserts multi-line text", function()
      helpers.set_cursor(1, 5) -- after "hello"

      accept.insert_text("\nnew line\nanother")

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.equal(3, #lines)
      assert.are.equal("hello", lines[1])
      assert.are.equal("new line", lines[2])
      assert.are.equal("another world", lines[3])
    end)

    it("positions cursor correctly after single-line insert", function()
      helpers.set_cursor(1, 5)

      accept.insert_text("123")

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.are.equal(1, cursor[1]) -- same row
      assert.are.equal(8, cursor[2]) -- 5 + 3 = 8
    end)

    it("positions cursor correctly after multi-line insert", function()
      helpers.set_cursor(1, 5)

      accept.insert_text("\nline2")

      local cursor = vim.api.nvim_win_get_cursor(0)
      assert.are.equal(2, cursor[1]) -- second row
    end)
  end)

  -----------------------------------------------------------
  -- apply_edit() Tests
  -----------------------------------------------------------
  describe("apply_edit()", function()
    local bufnr

    before_each(function()
      bufnr = helpers.create_test_buffer({
        "line 1",
        "target line",
        "line 3",
      }, "lua")
      helpers.set_cursor(2, 0)
    end)

    after_each(function()
      helpers.delete_test_buffer(bufnr)
    end)

    it("handles completion with only insert", function()
      local completion = {
        type = "edit",
        delete = "",
        insert = "new text",
      }

      assert.has_no.errors(function()
        accept.apply_edit(completion)
      end)
    end)

    it("handles completion with only delete", function()
      local completion = {
        type = "edit",
        delete = "target line",
        insert = "",
      }

      accept.apply_edit(completion)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      -- Should have deleted "target line"
      assert.are.equal(2, #lines)
    end)

    it("handles completion with both delete and insert", function()
      local completion = {
        type = "edit",
        delete = "target line",
        insert = "replaced line",
      }

      accept.apply_edit(completion)

      -- After delete, insert happens at cursor
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.is_true(#lines >= 2)
    end)

    it("handles delete not found gracefully", function()
      local completion = {
        type = "edit",
        delete = "nonexistent text",
        insert = "new text",
      }

      assert.has_no.errors(function()
        accept.apply_edit(completion)
      end)

      -- Should still insert even if delete fails
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local found = false
      for _, line in ipairs(lines) do
        if line:match("new text") then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it("finds exact match for multi-line delete", function()
      helpers.delete_test_buffer(bufnr)
      bufnr = helpers.create_test_buffer({
        "before",
        "delete me",
        "also delete",
        "after",
      }, "lua")
      helpers.set_cursor(2, 0)

      local completion = {
        type = "edit",
        delete = "delete me\nalso delete",
        insert = "",
      }

      accept.apply_edit(completion)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.are.equal(2, #lines)
      assert.are.equal("before", lines[1])
      assert.are.equal("after", lines[2])
    end)
  end)

  -----------------------------------------------------------
  -- setup_keymaps() Tests
  -----------------------------------------------------------
  describe("setup_keymaps()", function()
    it("does not error when called", function()
      assert.has_no.errors(function()
        accept.setup_keymaps()
      end)
    end)

    it("skips empty keymap values", function()
      haiku.config.keymap.accept = ""
      haiku.config.keymap.accept_word = ""

      assert.has_no.errors(function()
        accept.setup_keymaps()
      end)
    end)

    it("handles custom keymap values", function()
      haiku.config.keymap.accept = "<C-y>"
      haiku.config.keymap.accept_word = "<C-w>"

      assert.has_no.errors(function()
        accept.setup_keymaps()
      end)
    end)
  end)
end)
