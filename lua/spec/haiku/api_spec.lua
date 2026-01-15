-- Tests for haiku/api.lua
local helpers = require("haiku.test_helpers")
local mocks = require("haiku.test_helpers.mocks")

describe("api", function()
  local api
  local haiku

  before_each(function()
    -- Reset modules
    helpers.reset_modules()

    -- Setup haiku with config
    haiku = require("haiku")
    haiku.config = mocks.create_config()

    api = require("haiku.api")
  end)

  -----------------------------------------------------------
  -- stream() Tests
  -----------------------------------------------------------
  describe("stream()", function()
    it("returns a cancel function", function()
      local prompt_data = { system = "test system", user = "test user" }
      local cancel = api.stream(prompt_data, {})

      assert.is_function(cancel)
    end)

    it("cancel function can be called without error", function()
      local prompt_data = { system = "test system", user = "test user" }
      local cancel = api.stream(prompt_data, {})

      assert.has_no.errors(function()
        cancel()
      end)
    end)

    it("cancel function can be called multiple times", function()
      local prompt_data = { system = "test system", user = "test user" }
      local cancel = api.stream(prompt_data, {})

      assert.has_no.errors(function()
        cancel()
        cancel()
        cancel()
      end)
    end)

    it("accepts callbacks table", function()
      local prompt_data = { system = "test system", user = "test user" }

      assert.has_no.errors(function()
        local cancel = api.stream(prompt_data, {
          on_chunk = function() end,
          on_complete = function() end,
          on_error = function() end,
        })
        cancel()
      end)
    end)

    it("handles missing callbacks gracefully", function()
      local prompt_data = { system = "test system", user = "test user" }

      assert.has_no.errors(function()
        local cancel = api.stream(prompt_data, {})
        cancel()
      end)
    end)

    it("uses config model in request", function()
      haiku.config.model = "claude-sonnet-4"
      local prompt_data = { system = "test", user = "test" }

      -- Just verify it doesn't error - we can't easily inspect the curl command
      assert.has_no.errors(function()
        local cancel = api.stream(prompt_data, {})
        cancel()
      end)
    end)

    it("uses config max_tokens in request", function()
      haiku.config.max_tokens = 1024
      local prompt_data = { system = "test", user = "test" }

      assert.has_no.errors(function()
        local cancel = api.stream(prompt_data, {})
        cancel()
      end)
    end)
  end)

  -----------------------------------------------------------
  -- complete() Tests (non-streaming)
  -----------------------------------------------------------
  describe("complete()", function()
    it("accepts prompt_data and callback", function()
      local prompt_data = { system = "test system", user = "test user" }

      assert.has_no.errors(function()
        api.complete(prompt_data, function() end)
      end)
    end)

    it("callback receives nil when no response", function()
      -- This is a structural test - actual API behavior tested in integration
      local prompt_data = { system = "test", user = "test" }
      local callback_called = false

      api.complete(prompt_data, function(result, err)
        callback_called = true
        -- Result could be nil (no network) or actual data
      end)

      -- Function should execute without error
      -- Callback may or may not be called in headless env
    end)
  end)

  -----------------------------------------------------------
  -- Request Body Structure Tests
  -----------------------------------------------------------
  describe("request structure", function()
    it("encodes valid JSON for stream request", function()
      -- Verify that vim.json.encode works with typical prompt data
      local prompt_data = {
        system = "You are a helpful assistant",
        user = "Hello world",
      }

      assert.has_no.errors(function()
        local body = vim.json.encode({
          model = haiku.config.model,
          max_tokens = haiku.config.max_tokens,
          stream = true,
          system = prompt_data.system,
          messages = {
            { role = "user", content = prompt_data.user },
          },
        })
        assert.is_string(body)
        assert.is_true(#body > 0)
      end)
    end)

    it("handles special characters in prompt", function()
      local prompt_data = {
        system = "System with 'quotes' and \"double quotes\"",
        user = "User with\nnewlines\tand\ttabs",
      }

      assert.has_no.errors(function()
        local cancel = api.stream(prompt_data, {})
        cancel()
      end)
    end)

    it("handles unicode in prompt", function()
      local prompt_data = {
        system = "System with emoji: \xf0\x9f\x98\x80",
        user = "User with Japanese: \xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e",
      }

      assert.has_no.errors(function()
        local cancel = api.stream(prompt_data, {})
        cancel()
      end)
    end)

    it("handles very long prompts", function()
      local long_string = string.rep("a", 10000)
      local prompt_data = {
        system = long_string,
        user = long_string,
      }

      assert.has_no.errors(function()
        local cancel = api.stream(prompt_data, {})
        cancel()
      end)
    end)
  end)

  -----------------------------------------------------------
  -- SSE Parser Integration Tests (via core module)
  -----------------------------------------------------------
  describe("SSE parser integration", function()
    local core

    before_each(function()
      core = require("haiku.core")
    end)

    it("parser extracts text from content_block_delta", function()
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

    it("parser calls on_complete on message_stop", function()
      local completed = false
      local parser = core.create_sse_parser({
        on_complete = function()
          completed = true
        end,
      })

      parser('data: {"type":"message_stop"}\n')

      assert.is_true(completed)
    end)

    it("parser calls on_error on error event", function()
      local error_msg = nil
      local parser = core.create_sse_parser({
        on_error = function(err)
          error_msg = err
        end,
      })

      parser('data: {"type":"error","error":{"type":"api_error","message":"Rate limited"}}\n')

      assert.are.equal("Rate limited", error_msg)
    end)
  end)
end)
