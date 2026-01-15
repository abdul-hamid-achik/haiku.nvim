-- Tests for haiku/render.lua
local mocks = require("haiku.test_helpers.mocks")
local helpers = require("haiku.test_helpers")

describe("render", function()
  local render
  local haiku

  before_each(function()
    -- Reset modules
    helpers.reset_modules()

    -- Setup haiku with config
    haiku = require("haiku")
    haiku.config = mocks.create_config()

    render = require("haiku.render")
  end)

  after_each(function()
    pcall(function() render.clear() end)
  end)

  -----------------------------------------------------------
  -- State Management Tests
  -----------------------------------------------------------
  describe("get_state()", function()
    it("returns state object", function()
      local state = render.get_state()

      assert.is_table(state)
      assert.is_table(state.completions)
      assert.is_number(state.current_index)
    end)

    it("returns deep copy (modifications don't affect original)", function()
      local state1 = render.get_state()
      state1.current_index = 999

      local state2 = render.get_state()
      assert.are_not.equal(999, state2.current_index)
    end)
  end)

  describe("has_completion()", function()
    it("returns false when no completion", function()
      render.clear()
      assert.is_false(render.has_completion())
    end)

    it("returns true when completion exists", function()
      local bufnr = helpers.create_test_buffer({ "test" }, "lua")
      helpers.set_cursor(1, 4)

      local completion = mocks.create_insert_completion("hello")
      local ctx = { row = 1, col = 4 }

      render.show(completion, ctx)

      assert.is_true(render.has_completion())

      helpers.delete_test_buffer(bufnr)
    end)
  end)

  describe("get_current()", function()
    it("returns nil when no completion", function()
      render.clear()
      assert.is_nil(render.get_current())
    end)

    it("returns completion when one exists", function()
      local bufnr = helpers.create_test_buffer({ "test" }, "lua")
      helpers.set_cursor(1, 4)

      local completion = mocks.create_insert_completion("hello")
      local ctx = { row = 1, col = 4 }

      render.show(completion, ctx)

      local current = render.get_current()
      assert.is_not_nil(current)
      assert.are.equal("insert", current.type)
      assert.are.equal("hello", current.text)

      helpers.delete_test_buffer(bufnr)
    end)
  end)

  describe("get_current_text()", function()
    it("returns nil when no completion", function()
      render.clear()
      assert.is_nil(render.get_current_text())
    end)

    it("returns text for INSERT type", function()
      local bufnr = helpers.create_test_buffer({ "test" }, "lua")
      helpers.set_cursor(1, 4)

      local completion = mocks.create_insert_completion("hello world")
      local ctx = { row = 1, col = 4 }

      render.show(completion, ctx)

      assert.are.equal("hello world", render.get_current_text())

      helpers.delete_test_buffer(bufnr)
    end)

    it("returns insert field for EDIT type", function()
      local bufnr = helpers.create_test_buffer({ "test" }, "lua")
      helpers.set_cursor(1, 4)

      local completion = mocks.create_edit_completion("old", "new")
      local ctx = { row = 1, col = 4 }

      render.show(completion, ctx)

      assert.are.equal("new", render.get_current_text())

      helpers.delete_test_buffer(bufnr)
    end)
  end)

  -----------------------------------------------------------
  -- Suggestion Management Tests
  -----------------------------------------------------------
  describe("add_suggestion()", function()
    local bufnr, ctx

    before_each(function()
      bufnr = helpers.create_test_buffer({ "test" }, "lua")
      helpers.set_cursor(1, 4)
      ctx = { row = 1, col = 4 }
    end)

    after_each(function()
      helpers.delete_test_buffer(bufnr)
    end)

    it("adds completion to suggestions", function()
      local completion = mocks.create_insert_completion("hello")

      render.add_suggestion(completion, ctx)

      assert.are.equal(1, render.get_suggestion_count())
    end)

    it("prevents duplicate suggestions", function()
      local completion1 = mocks.create_insert_completion("hello")
      local completion2 = mocks.create_insert_completion("hello")

      render.add_suggestion(completion1, ctx)
      render.add_suggestion(completion2, ctx)

      assert.are.equal(1, render.get_suggestion_count())
    end)

    it("allows different suggestions", function()
      local completion1 = mocks.create_insert_completion("hello")
      local completion2 = mocks.create_insert_completion("world")

      render.add_suggestion(completion1, ctx)
      render.add_suggestion(completion2, ctx)

      assert.are.equal(2, render.get_suggestion_count())
    end)

    it("resets when position changes", function()
      local completion1 = mocks.create_insert_completion("hello")
      render.add_suggestion(completion1, ctx)

      -- Change position
      helpers.set_cursor(1, 2)
      local new_ctx = { row = 1, col = 2 }
      local completion2 = mocks.create_insert_completion("world")
      render.add_suggestion(completion2, new_ctx)

      -- Should have reset and only have the new one
      assert.are.equal(1, render.get_suggestion_count())
    end)

    it("does not add nil completion", function()
      render.add_suggestion(nil, ctx)

      assert.are.equal(0, render.get_suggestion_count())
    end)
  end)

  describe("get_suggestion_count()", function()
    it("returns 0 when no suggestions", function()
      render.clear()
      assert.are.equal(0, render.get_suggestion_count())
    end)
  end)

  describe("get_current_index()", function()
    it("returns 0 when no suggestions", function()
      render.clear()
      assert.are.equal(0, render.get_current_index())
    end)

    it("returns index when suggestions exist", function()
      local bufnr = helpers.create_test_buffer({ "test" }, "lua")
      helpers.set_cursor(1, 4)
      local ctx = { row = 1, col = 4 }

      local completion = mocks.create_insert_completion("hello")
      render.add_suggestion(completion, ctx)

      assert.are.equal(1, render.get_current_index())

      helpers.delete_test_buffer(bufnr)
    end)
  end)

  -----------------------------------------------------------
  -- Suggestion Cycling Tests
  -----------------------------------------------------------
  describe("next_suggestion()", function()
    local bufnr, ctx

    before_each(function()
      bufnr = helpers.create_test_buffer({ "test" }, "lua")
      helpers.set_cursor(1, 4)
      ctx = { row = 1, col = 4 }
    end)

    after_each(function()
      helpers.delete_test_buffer(bufnr)
    end)

    it("returns false when no suggestions", function()
      render.clear()
      assert.is_false(render.next_suggestion())
    end)

    it("returns false when at end", function()
      local completion = mocks.create_insert_completion("hello")
      render.add_suggestion(completion, ctx)

      -- Already at the only suggestion
      assert.is_false(render.next_suggestion())
    end)

    it("advances to next suggestion", function()
      local completion1 = mocks.create_insert_completion("first")
      local completion2 = mocks.create_insert_completion("second")

      render.add_suggestion(completion1, ctx)
      render.add_suggestion(completion2, ctx)

      -- Currently at index 2 (last added)
      assert.are.equal(2, render.get_current_index())

      -- Go back to test forward
      render.prev_suggestion()
      assert.are.equal(1, render.get_current_index())

      -- Now go forward
      local result = render.next_suggestion()
      assert.is_true(result)
      assert.are.equal(2, render.get_current_index())
    end)
  end)

  describe("prev_suggestion()", function()
    local bufnr, ctx

    before_each(function()
      bufnr = helpers.create_test_buffer({ "test" }, "lua")
      helpers.set_cursor(1, 4)
      ctx = { row = 1, col = 4 }
    end)

    after_each(function()
      helpers.delete_test_buffer(bufnr)
    end)

    it("returns false when no suggestions", function()
      render.clear()
      assert.is_false(render.prev_suggestion())
    end)

    it("returns false when at index 1", function()
      local completion = mocks.create_insert_completion("hello")
      render.add_suggestion(completion, ctx)

      -- Move to first
      render.prev_suggestion() -- Should fail, already at 1

      assert.is_false(render.prev_suggestion())
    end)

    it("moves to previous suggestion", function()
      local completion1 = mocks.create_insert_completion("first")
      local completion2 = mocks.create_insert_completion("second")

      render.add_suggestion(completion1, ctx)
      render.add_suggestion(completion2, ctx)

      -- Currently at index 2
      assert.are.equal(2, render.get_current_index())

      local result = render.prev_suggestion()
      assert.is_true(result)
      assert.are.equal(1, render.get_current_index())
    end)
  end)

  -----------------------------------------------------------
  -- Clear Tests
  -----------------------------------------------------------
  describe("clear()", function()
    it("resets all state", function()
      local bufnr = helpers.create_test_buffer({ "test" }, "lua")
      helpers.set_cursor(1, 4)
      local ctx = { row = 1, col = 4 }

      local completion = mocks.create_insert_completion("hello")
      render.add_suggestion(completion, ctx)

      render.clear()

      assert.is_false(render.has_completion())
      assert.are.equal(0, render.get_suggestion_count())
      assert.are.equal(0, render.get_current_index())

      helpers.delete_test_buffer(bufnr)
    end)

    it("does not error when nothing to clear", function()
      assert.has_no.errors(function()
        render.clear()
        render.clear()
      end)
    end)
  end)

  -----------------------------------------------------------
  -- Display Tests (verify no errors)
  -----------------------------------------------------------
  describe("show()", function()
    it("handles nil completion", function()
      assert.has_no.errors(function()
        render.show(nil, { row = 1, col = 0 })
      end)
    end)

    it("handles INSERT type without error", function()
      local bufnr = helpers.create_test_buffer({ "test" }, "lua")
      helpers.set_cursor(1, 4)

      assert.has_no.errors(function()
        local completion = mocks.create_insert_completion("hello")
        render.show(completion, { row = 1, col = 4 })
      end)

      helpers.delete_test_buffer(bufnr)
    end)

    it("creates extmark for INSERT completion", function()
      local bufnr = helpers.create_test_buffer({ "test" }, "lua")
      helpers.set_cursor(1, 4)

      local completion = mocks.create_insert_completion("hello")
      render.show(completion, { row = 1, col = 4 })

      -- Verify extmark exists
      local extmarks = vim.api.nvim_buf_get_extmarks(
        bufnr, render.namespace, 0, -1, {}
      )
      assert.is_true(#extmarks > 0, "Expected at least one extmark to be created")

      helpers.delete_test_buffer(bufnr)
    end)

    it("handles EDIT type without error", function()
      local bufnr = helpers.create_test_buffer({ "test" }, "lua")
      helpers.set_cursor(1, 4)

      assert.has_no.errors(function()
        local completion = mocks.create_edit_completion("old", "new")
        render.show(completion, { row = 1, col = 4 })
      end)

      helpers.delete_test_buffer(bufnr)
    end)

    it("handles multi-line INSERT without error", function()
      local bufnr = helpers.create_test_buffer({ "test" }, "lua")
      helpers.set_cursor(1, 4)

      assert.has_no.errors(function()
        local completion = mocks.create_insert_completion("line1\nline2\nline3")
        render.show(completion, { row = 1, col = 4 })
      end)

      helpers.delete_test_buffer(bufnr)
    end)
  end)

  describe("update_text()", function()
    it("clears when text is empty", function()
      local bufnr = helpers.create_test_buffer({ "test" }, "lua")
      helpers.set_cursor(1, 4)

      local completion = mocks.create_insert_completion("hello")
      render.show(completion, { row = 1, col = 4 })

      render.update_text("")

      assert.is_false(render.has_completion())

      helpers.delete_test_buffer(bufnr)
    end)

    it("does not error when no completion", function()
      assert.has_no.errors(function()
        render.update_text("new text")
      end)
    end)
  end)
end)
