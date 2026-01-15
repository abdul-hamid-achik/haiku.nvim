-- Tests for haiku/trigger.lua
local mocks = require("haiku.test_helpers.mocks")
local helpers = require("haiku.test_helpers")

describe("trigger", function()
  local trigger
  local haiku

  before_each(function()
    -- Reset all haiku modules
    helpers.reset_modules()

    -- Setup haiku with config
    haiku = require("haiku")
    haiku.config = mocks.create_config()
    haiku.enabled = true
    haiku.is_enabled = function() return haiku.enabled end
    haiku.is_filetype_enabled = function() return true end

    trigger = require("haiku.trigger")
  end)

  after_each(function()
    -- Disable to clean up autocmds and timers
    pcall(function() trigger.disable() end)
    pcall(function() trigger.cleanup() end)
  end)

  -----------------------------------------------------------
  -- should_skip_verbose() Tests
  -- Note: These tests run in normal mode since headless Neovim
  -- doesn't support startinsert. We test the skip conditions
  -- that don't require insert mode, and verify mode check works.
  -----------------------------------------------------------
  describe("should_skip_verbose()", function()
    local bufnr

    before_each(function()
      bufnr = helpers.create_test_buffer({ "local x = 123" }, "lua")
      helpers.set_cursor(1, 10)
    end)

    after_each(function()
      helpers.delete_test_buffer(bufnr)
    end)

    it("returns true with reason when plugin disabled", function()
      haiku.enabled = false

      local skip, reason = trigger.should_skip_verbose()

      assert.is_true(skip)
      assert.are.equal("Plugin not enabled", reason)
    end)

    it("returns true with reason when not in insert mode", function()
      -- We're in normal mode by default in tests
      local skip, reason = trigger.should_skip_verbose()

      assert.is_true(skip)
      assert.matches("Not in insert mode", reason)
    end)

    it("checks mode before filetype", function()
      -- Mode check comes before filetype check
      haiku.is_filetype_enabled = function() return false end

      local skip, reason = trigger.should_skip_verbose()

      -- Should fail on mode first, not filetype
      assert.is_true(skip)
      assert.matches("Not in insert mode", reason)
    end)

    it("checks mode before buffer size", function()
      -- Create a large buffer
      local large_lines = {}
      for i = 1, 15000 do
        table.insert(large_lines, "line " .. i)
      end
      helpers.delete_test_buffer(bufnr)
      bufnr = helpers.create_test_buffer(large_lines, "lua")

      local skip, reason = trigger.should_skip_verbose()

      -- Should fail on mode first, not buffer size
      assert.is_true(skip)
      assert.matches("Not in insert mode", reason)
    end)

    it("includes mode in reason when not in insert mode", function()
      local skip, reason = trigger.should_skip_verbose()

      assert.is_true(skip)
      assert.matches("mode=n", reason)
    end)
  end)

  -----------------------------------------------------------
  -- should_skip() Tests
  -----------------------------------------------------------
  describe("should_skip()", function()
    local bufnr

    before_each(function()
      bufnr = helpers.create_test_buffer({ "local x = 123" }, "lua")
      helpers.set_cursor(1, 10)
    end)

    after_each(function()
      helpers.delete_test_buffer(bufnr)
    end)

    it("returns true when plugin disabled", function()
      haiku.enabled = false

      assert.is_true(trigger.should_skip())
    end)

    it("returns true when not in insert mode", function()
      -- We're in normal mode by default
      assert.is_true(trigger.should_skip())
    end)
  end)

  -----------------------------------------------------------
  -- in_comment_or_string() Tests
  -- Note: Treesitter behavior in headless mode may vary.
  -- These tests verify the function doesn't error and returns
  -- a boolean, without strict assertions on treesitter detection.
  -----------------------------------------------------------
  describe("in_comment_or_string()", function()
    it("returns false when treesitter unavailable", function()
      -- Create buffer without treesitter parser (text filetype)
      local bufnr = helpers.create_test_buffer({ "hello" }, "text")
      helpers.set_cursor(1, 2)

      local result = trigger.in_comment_or_string()

      -- Should return false when no treesitter
      assert.is_false(result)

      helpers.delete_test_buffer(bufnr)
    end)

    it("returns a boolean for lua code", function()
      local bufnr = helpers.create_test_buffer({ "local x = 1" }, "lua")
      helpers.set_cursor(1, 5)

      local result = trigger.in_comment_or_string()

      -- Should return a boolean (treesitter may or may not be available)
      assert.is_boolean(result)

      helpers.delete_test_buffer(bufnr)
    end)

    it("returns a boolean for lua comment", function()
      local bufnr = helpers.create_test_buffer({ "-- this is a comment" }, "lua")
      helpers.set_cursor(1, 10)

      local result = trigger.in_comment_or_string()

      -- Should return a boolean
      assert.is_boolean(result)

      helpers.delete_test_buffer(bufnr)
    end)

    it("returns a boolean for lua string", function()
      local bufnr = helpers.create_test_buffer({ 'local s = "hello"' }, "lua")
      helpers.set_cursor(1, 13)

      local result = trigger.in_comment_or_string()

      -- Should return a boolean
      assert.is_boolean(result)

      helpers.delete_test_buffer(bufnr)
    end)

    it("does not error on invalid buffer", function()
      assert.has_no.errors(function()
        trigger.in_comment_or_string()
      end)
    end)
  end)

  -----------------------------------------------------------
  -- State Management Tests
  -----------------------------------------------------------
  describe("enable()/disable()", function()
    it("enable() sets enabled state", function()
      -- Setup needs to be called first
      trigger.setup()

      -- Check that trigger works (doesn't error)
      assert.has_no.errors(function()
        trigger.enable()
      end)
    end)

    it("disable() cleans up", function()
      trigger.setup()
      trigger.enable()

      assert.has_no.errors(function()
        trigger.disable()
      end)
    end)

    it("cancel() stops timers without error", function()
      trigger.setup()

      assert.has_no.errors(function()
        trigger.cancel()
      end)
    end)

    it("cleanup() cleans up all resources", function()
      trigger.setup()

      assert.has_no.errors(function()
        trigger.cleanup()
      end)
    end)
  end)
end)
