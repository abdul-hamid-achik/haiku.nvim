-- Tests for haiku/init.lua
local helpers = require("haiku.test_helpers")

describe("init", function()
  local haiku

  before_each(function()
    -- Reset all haiku modules
    helpers.reset_modules()

    -- Clear environment variables for consistent tests
    vim.env.HAIKU_API_KEY = nil
    vim.env.ANTHROPIC_API_KEY = nil

    haiku = require("haiku")
  end)

  after_each(function()
    -- Clean up
    pcall(function()
      if haiku.initialized then
        haiku.disable()
      end
    end)

    -- Reset state
    haiku.enabled = false
    haiku.initialized = false
    haiku.use_cmp = false
    haiku.config = {}
  end)

  -----------------------------------------------------------
  -- Configuration Validation Tests
  -----------------------------------------------------------
  describe("validate_config (via setup)", function()
    it("accepts valid configuration", function()
      haiku.setup({ api_key = "test-key" })

      assert.is_true(haiku.initialized)
      assert.are.equal("test-key", haiku.config.api_key)
    end)

    it("rejects non-string api_key", function()
      local notified = false
      local original_notify = vim.notify
      vim.notify = function(msg)
        if msg:match("api_key must be a string") then
          notified = true
        end
      end

      haiku.setup({ api_key = 12345 })

      vim.notify = original_notify
      assert.is_true(notified)
      assert.is_false(haiku.initialized)
    end)

    it("rejects non-numeric debounce_ms", function()
      local notified = false
      local original_notify = vim.notify
      vim.notify = function(msg)
        if msg:match("debounce_ms must be a number") then
          notified = true
        end
      end

      haiku.setup({ api_key = "test-key", debounce_ms = "fast" })

      vim.notify = original_notify
      assert.is_true(notified)
      assert.is_false(haiku.initialized)
    end)

    it("rejects negative limits", function()
      local notified = false
      local original_notify = vim.notify
      vim.notify = function(msg)
        if msg:match("must be a positive number") then
          notified = true
        end
      end

      haiku.setup({
        api_key = "test-key",
        limits = { max_buffer_lines = -100 }
      })

      vim.notify = original_notify
      assert.is_true(notified)
      assert.is_false(haiku.initialized)
    end)

    it("rejects missing required tables", function()
      local notified = false
      local original_notify = vim.notify
      vim.notify = function(msg)
        if msg:match("configuration section is missing") then
          notified = true
        end
      end

      -- Directly corrupt a required section
      local corrupt_config = vim.tbl_deep_extend("force", haiku.defaults, {
        api_key = "test-key",
        trigger = "not a table",
      })
      haiku.config = corrupt_config

      -- Manually trigger validation path by calling setup with corrupt config
      haiku.setup({ api_key = "test-key", trigger = "not a table" })

      vim.notify = original_notify
      assert.is_true(notified)
    end)

    it("rejects zero debounce_ms", function()
      local notified = false
      local original_notify = vim.notify
      vim.notify = function(msg)
        if msg:match("debounce_ms must be greater than 0") then
          notified = true
        end
      end

      haiku.setup({ api_key = "test-key", debounce_ms = 0 })

      vim.notify = original_notify
      assert.is_true(notified)
      assert.is_false(haiku.initialized)
    end)

    it("rejects negative debounce_ms", function()
      local notified = false
      local original_notify = vim.notify
      vim.notify = function(msg)
        if msg:match("debounce_ms must be greater than 0") then
          notified = true
        end
      end

      haiku.setup({ api_key = "test-key", debounce_ms = -100 })

      vim.notify = original_notify
      assert.is_true(notified)
      assert.is_false(haiku.initialized)
    end)

    it("rejects zero min_chars", function()
      local notified = false
      local original_notify = vim.notify
      vim.notify = function(msg)
        if msg:match("min_chars must be at least 1") then
          notified = true
        end
      end

      haiku.setup({ api_key = "test-key", min_chars = 0 })

      vim.notify = original_notify
      assert.is_true(notified)
      assert.is_false(haiku.initialized)
    end)

    it("rejects zero idle_trigger_ms", function()
      local notified = false
      local original_notify = vim.notify
      vim.notify = function(msg)
        if msg:match("idle_trigger_ms must be greater than 0") then
          notified = true
        end
      end

      haiku.setup({ api_key = "test-key", idle_trigger_ms = 0 })

      vim.notify = original_notify
      assert.is_true(notified)
      assert.is_false(haiku.initialized)
    end)

    it("rejects zero max_tokens", function()
      local notified = false
      local original_notify = vim.notify
      vim.notify = function(msg)
        if msg:match("max_tokens must be greater than 0") then
          notified = true
        end
      end

      haiku.setup({ api_key = "test-key", max_tokens = 0 })

      vim.notify = original_notify
      assert.is_true(notified)
      assert.is_false(haiku.initialized)
    end)

    it("rejects max_tokens exceeding 4096", function()
      local notified = false
      local original_notify = vim.notify
      vim.notify = function(msg)
        if msg:match("max_tokens cannot exceed 4096") then
          notified = true
        end
      end

      haiku.setup({ api_key = "test-key", max_tokens = 5000 })

      vim.notify = original_notify
      assert.is_true(notified)
      assert.is_false(haiku.initialized)
    end)

    it("rejects whitespace-only api_key", function()
      local notified = false
      local original_notify = vim.notify
      vim.notify = function(msg)
        if msg:match("api_key cannot be empty or whitespace%-only") then
          notified = true
        end
      end

      haiku.setup({ api_key = "   " })

      vim.notify = original_notify
      assert.is_true(notified)
      assert.is_false(haiku.initialized)
    end)

    it("accepts valid bounds", function()
      haiku.setup({
        api_key = "test-key",
        debounce_ms = 1,
        min_chars = 1,
        idle_trigger_ms = 1,
        max_tokens = 4096,
      })

      assert.is_true(haiku.initialized)
    end)
  end)

  -----------------------------------------------------------
  -- API Key Resolution Tests
  -----------------------------------------------------------
  describe("API key resolution", function()
    it("uses api_key from config when provided", function()
      vim.env.HAIKU_API_KEY = "env-haiku-key"
      vim.env.ANTHROPIC_API_KEY = "env-anthropic-key"

      haiku.setup({ api_key = "config-key" })

      assert.are.equal("config-key", haiku.config.api_key)
    end)

    it("falls back to HAIKU_API_KEY env var", function()
      vim.env.HAIKU_API_KEY = "env-haiku-key"
      vim.env.ANTHROPIC_API_KEY = "env-anthropic-key"

      haiku.setup({})

      assert.are.equal("env-haiku-key", haiku.config.api_key)
    end)

    it("falls back to ANTHROPIC_API_KEY env var", function()
      vim.env.ANTHROPIC_API_KEY = "env-anthropic-key"

      haiku.setup({})

      assert.are.equal("env-anthropic-key", haiku.config.api_key)
    end)

    it("reports error when no API key available", function()
      local notified = false
      local original_notify = vim.notify
      vim.notify = function(msg)
        if msg:match("API key required") then
          notified = true
        end
      end

      haiku.setup({})

      vim.notify = original_notify
      assert.is_true(notified)
      assert.is_false(haiku.initialized)
    end)
  end)

  -----------------------------------------------------------
  -- Filetype Handling Tests
  -----------------------------------------------------------
  describe("is_filetype_enabled()", function()
    before_each(function()
      vim.env.ANTHROPIC_API_KEY = "test-key"
      haiku.setup({})
    end)

    it("enables all filetypes with '*' wildcard", function()
      assert.is_true(haiku.is_filetype_enabled("lua"))
      assert.is_true(haiku.is_filetype_enabled("python"))
      assert.is_true(haiku.is_filetype_enabled("typescript"))
      assert.is_true(haiku.is_filetype_enabled("rust"))
    end)

    it("respects disabled_ft list", function()
      -- TelescopePrompt is in default disabled list
      assert.is_false(haiku.is_filetype_enabled("TelescopePrompt"))
      assert.is_false(haiku.is_filetype_enabled("NvimTree"))
      assert.is_false(haiku.is_filetype_enabled("help"))
    end)

    it("disabled list takes priority over wildcard", function()
      haiku.config.enabled_ft = { "*" }
      haiku.config.disabled_ft = { "markdown" }

      assert.is_false(haiku.is_filetype_enabled("markdown"))
    end)

    it("handles specific enabled_ft list without wildcard", function()
      haiku.config.enabled_ft = { "lua", "python" }
      haiku.config.disabled_ft = {}

      assert.is_true(haiku.is_filetype_enabled("lua"))
      assert.is_true(haiku.is_filetype_enabled("python"))
      assert.is_false(haiku.is_filetype_enabled("rust"))
    end)

    it("handles empty filetype string", function()
      -- Empty string should not match "*" in the normal sense
      -- but since it's checked against enabled_ft, it depends on implementation
      local result = haiku.is_filetype_enabled("")
      assert.is_boolean(result)
    end)

    it("uses current buffer filetype when not specified", function()
      -- Create a test buffer with lua filetype
      local bufnr = helpers.create_test_buffer({ "test" }, "lua")

      local result = haiku.is_filetype_enabled()

      assert.is_true(result)
      helpers.delete_test_buffer(bufnr)
    end)
  end)

  -----------------------------------------------------------
  -- Lifecycle Tests (enable/disable/toggle)
  -----------------------------------------------------------
  describe("enable()", function()
    it("auto-initializes with defaults when not setup", function()
      vim.env.ANTHROPIC_API_KEY = "test-key"

      haiku.enable()

      assert.is_true(haiku.initialized)
      assert.is_true(haiku.enabled)
    end)

    it("does not enable if setup fails", function()
      -- No API key available
      haiku.enable()

      assert.is_false(haiku.initialized)
      assert.is_false(haiku.enabled)
    end)

    it("re-enables after disable", function()
      vim.env.ANTHROPIC_API_KEY = "test-key"
      haiku.setup({})
      haiku.disable()

      assert.is_false(haiku.enabled)

      haiku.enable()

      assert.is_true(haiku.enabled)
    end)
  end)

  describe("disable()", function()
    it("sets enabled to false", function()
      vim.env.ANTHROPIC_API_KEY = "test-key"
      haiku.setup({})

      haiku.disable()

      assert.is_false(haiku.enabled)
    end)

    it("can be called multiple times without error", function()
      vim.env.ANTHROPIC_API_KEY = "test-key"
      haiku.setup({})

      assert.has_no.errors(function()
        haiku.disable()
        haiku.disable()
        haiku.disable()
      end)
    end)
  end)

  describe("toggle()", function()
    it("enables when disabled", function()
      vim.env.ANTHROPIC_API_KEY = "test-key"
      haiku.setup({})
      haiku.disable()

      haiku.toggle()

      assert.is_true(haiku.enabled)
    end)

    it("disables when enabled", function()
      vim.env.ANTHROPIC_API_KEY = "test-key"
      haiku.setup({})

      haiku.toggle()

      assert.is_false(haiku.enabled)
    end)
  end)

  -----------------------------------------------------------
  -- is_enabled() Tests
  -----------------------------------------------------------
  describe("is_enabled()", function()
    it("returns false when not initialized", function()
      assert.is_false(haiku.is_enabled())
    end)

    it("returns false when initialized but disabled", function()
      vim.env.ANTHROPIC_API_KEY = "test-key"
      haiku.setup({})
      haiku.disable()

      assert.is_false(haiku.is_enabled())
    end)

    it("returns true when initialized and enabled", function()
      vim.env.ANTHROPIC_API_KEY = "test-key"
      haiku.setup({})

      assert.is_true(haiku.is_enabled())
    end)
  end)

  -----------------------------------------------------------
  -- status() Tests
  -----------------------------------------------------------
  describe("status()", function()
    it("returns correct status when not initialized", function()
      local status = haiku.status()

      assert.is_false(status.enabled)
      assert.is_false(status.initialized)
    end)

    it("returns correct status when initialized", function()
      vim.env.ANTHROPIC_API_KEY = "test-key"
      haiku.setup({})

      local status = haiku.status()

      assert.is_true(status.enabled)
      assert.is_true(status.initialized)
      assert.is_true(status.api_key_set)
      assert.are.equal("claude-haiku-4-5", status.model)
    end)

    it("reflects custom model setting", function()
      vim.env.ANTHROPIC_API_KEY = "test-key"
      haiku.setup({ model = "claude-sonnet-4" })

      local status = haiku.status()

      assert.are.equal("claude-sonnet-4", status.model)
    end)
  end)

  -----------------------------------------------------------
  -- set_debug() Tests
  -----------------------------------------------------------
  describe("set_debug()", function()
    it("warns when not initialized", function()
      local warned = false
      local original_notify = vim.notify
      vim.notify = function(msg)
        if msg:match("Not initialized") then
          warned = true
        end
      end

      haiku.set_debug(true)

      vim.notify = original_notify
      assert.is_true(warned)
    end)

    it("enables debug mode", function()
      vim.env.ANTHROPIC_API_KEY = "test-key"
      haiku.setup({})

      haiku.set_debug(true)

      assert.is_true(haiku.config.debug)
    end)

    it("disables debug mode", function()
      vim.env.ANTHROPIC_API_KEY = "test-key"
      haiku.setup({ debug = true })

      haiku.set_debug(false)

      assert.is_false(haiku.config.debug)
    end)

    it("toggles debug mode when called without argument", function()
      vim.env.ANTHROPIC_API_KEY = "test-key"
      haiku.setup({ debug = false })

      haiku.set_debug()
      assert.is_true(haiku.config.debug)

      haiku.set_debug()
      assert.is_false(haiku.config.debug)
    end)
  end)

  -----------------------------------------------------------
  -- Config Merging Tests
  -----------------------------------------------------------
  describe("config merging", function()
    it("preserves default values when not overridden", function()
      vim.env.ANTHROPIC_API_KEY = "test-key"
      haiku.setup({})

      assert.are.equal(300, haiku.config.debounce_ms)
      assert.are.equal(512, haiku.config.max_tokens)
      assert.are.equal(3, haiku.config.min_chars)
    end)

    it("overrides defaults with user config", function()
      vim.env.ANTHROPIC_API_KEY = "test-key"
      haiku.setup({
        debounce_ms = 500,
        max_tokens = 1024,
      })

      assert.are.equal(500, haiku.config.debounce_ms)
      assert.are.equal(1024, haiku.config.max_tokens)
    end)

    it("deep merges nested tables", function()
      vim.env.ANTHROPIC_API_KEY = "test-key"
      haiku.setup({
        trigger = {
          on_insert = false,
          -- other trigger options should preserve defaults
        },
      })

      assert.is_false(haiku.config.trigger.on_insert)
      assert.is_true(haiku.config.trigger.on_idle) -- default preserved
    end)

    it("preserves custom keymaps", function()
      vim.env.ANTHROPIC_API_KEY = "test-key"
      haiku.setup({
        keymap = {
          accept = "<C-y>",
        },
      })

      assert.are.equal("<C-y>", haiku.config.keymap.accept)
      assert.are.equal("<C-Right>", haiku.config.keymap.accept_word) -- default preserved
    end)
  end)

  -----------------------------------------------------------
  -- Cache Initialization Tests
  -----------------------------------------------------------
  describe("cache initialization", function()
    it("initializes cache with config values", function()
      vim.env.ANTHROPIC_API_KEY = "test-key"
      haiku.setup({
        cache = {
          max_size = 100,
          ttl_seconds = 600,
        },
      })

      local cache = require("haiku.cache")
      local stats = cache.stats()

      assert.are.equal(100, stats.max_size)
      assert.are.equal(600, cache.get_ttl())
    end)
  end)
end)
