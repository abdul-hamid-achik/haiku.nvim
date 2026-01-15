-- Tests for haiku/cache.lua
local mocks = require("haiku.test_helpers.mocks")

describe("cache", function()
  local cache

  before_each(function()
    -- Fresh module for each test
    package.loaded["haiku.cache"] = nil
    cache = require("haiku.cache")
    cache.clear()
    cache.set_max_size(50)
    cache.set_ttl(300)
  end)

  describe("make_key()", function()
    it("generates a string key", function()
      local ctx = mocks.create_context()
      local key = cache.make_key(ctx)

      assert.is_string(key)
      assert.is_true(#key > 0)
    end)

    it("generates consistent keys for same context", function()
      local ctx = mocks.create_context()
      local key1 = cache.make_key(ctx)
      local key2 = cache.make_key(ctx)

      assert.are.equal(key1, key2)
    end)

    it("generates different keys for different contexts", function()
      local ctx1 = mocks.create_context({ before_cursor = "local x = " })
      local ctx2 = mocks.create_context({ before_cursor = "local y = " })

      local key1 = cache.make_key(ctx1)
      local key2 = cache.make_key(ctx2)

      assert.are_not.equal(key1, key2)
    end)

    it("prevents collision with delimiter edge cases", function()
      -- These would collide without proper delimiting:
      -- filetype="lua", before="a|b", after="c" vs
      -- filetype="lua", before="a", after="b|c"
      local ctx1 = mocks.create_context({
        filetype = "lua",
        before_cursor = "a|b",
        after_cursor = "c",
      })
      local ctx2 = mocks.create_context({
        filetype = "lua",
        before_cursor = "a",
        after_cursor = "b|c",
      })

      local key1 = cache.make_key(ctx1)
      local key2 = cache.make_key(ctx2)

      assert.are_not.equal(key1, key2)
    end)

    it("includes filetype in key generation", function()
      local ctx1 = mocks.create_context({ filetype = "lua" })
      local ctx2 = mocks.create_context({ filetype = "python" })

      local key1 = cache.make_key(ctx1)
      local key2 = cache.make_key(ctx2)

      assert.are_not.equal(key1, key2)
    end)
  end)

  describe("get()", function()
    it("returns nil for missing keys", function()
      local result = cache.get("nonexistent_key")
      assert.is_nil(result)
    end)

    it("returns cached value", function()
      cache.set("test_key", "test_value")
      local result = cache.get("test_key")

      assert.are.equal("test_value", result)
    end)

    it("expires entries after TTL", function()
      -- Save original os.time
      local original_time = os.time
      local mock_time = original_time()

      -- Mock os.time to control time
      os.time = function() return mock_time end

      cache.set_ttl(10)  -- 10 second TTL
      cache.set("test_key", "test_value")

      -- Value exists before expiry
      assert.are.equal("test_value", cache.get("test_key"))

      -- Advance time past TTL
      mock_time = mock_time + 15

      -- Value should be expired now
      assert.is_nil(cache.get("test_key"))

      -- Restore original os.time
      os.time = original_time
    end)
  end)

  describe("set()", function()
    it("stores values", function()
      cache.set("key1", "value1")

      assert.are.equal(1, cache.size())
      assert.are.equal("value1", cache.get("key1"))
    end)

    it("updates existing keys", function()
      cache.set("key1", "value1")
      cache.set("key1", "value2")

      assert.are.equal(1, cache.size())
      assert.are.equal("value2", cache.get("key1"))
    end)

    it("evicts oldest when max_size exceeded", function()
      cache.set_max_size(3)

      cache.set("key1", "value1")
      cache.set("key2", "value2")
      cache.set("key3", "value3")
      cache.set("key4", "value4") -- Should evict key1

      assert.are.equal(3, cache.size())
      assert.is_nil(cache.get("key1"))
      assert.are.equal("value2", cache.get("key2"))
      assert.are.equal("value3", cache.get("key3"))
      assert.are.equal("value4", cache.get("key4"))
    end)
  end)

  describe("touch()", function()
    it("moves key to end of LRU order", function()
      cache.set_max_size(3)

      cache.set("key1", "value1")
      cache.set("key2", "value2")
      cache.set("key3", "value3")

      -- Touch key1 to make it most recently used
      cache.touch("key1")

      -- Add key4, should evict key2 (now oldest)
      cache.set("key4", "value4")

      assert.are.equal("value1", cache.get("key1"))
      assert.is_nil(cache.get("key2"))
      assert.are.equal("value3", cache.get("key3"))
      assert.are.equal("value4", cache.get("key4"))
    end)

    it("handles touch on non-existent key gracefully", function()
      assert.has_no.errors(function()
        cache.touch("non_existent_key")
      end)
      -- Should not add the key
      assert.are.equal(0, cache.size())
    end)
  end)

  describe("clear()", function()
    it("removes all entries", function()
      cache.set("key1", "value1")
      cache.set("key2", "value2")
      cache.set("key3", "value3")

      cache.clear()

      assert.are.equal(0, cache.size())
      assert.is_nil(cache.get("key1"))
      assert.is_nil(cache.get("key2"))
      assert.is_nil(cache.get("key3"))
    end)
  end)

  describe("stats()", function()
    it("returns correct size", function()
      cache.set("key1", "value1")
      cache.set("key2", "value2")

      local stats = cache.stats()

      assert.are.equal(2, stats.size)
      assert.are.equal(50, stats.max_size)
    end)

    it("returns correct max_size after change", function()
      cache.set_max_size(100)
      local stats = cache.stats()

      assert.are.equal(100, stats.max_size)
    end)
  end)

  describe("set_max_size()", function()
    it("evicts entries when reducing size", function()
      cache.set("key1", "value1")
      cache.set("key2", "value2")
      cache.set("key3", "value3")

      cache.set_max_size(2)

      assert.are.equal(2, cache.size())
      assert.is_nil(cache.get("key1")) -- Oldest should be evicted
    end)
  end)

  describe("set_ttl()", function()
    it("updates TTL setting", function()
      cache.set_ttl(600)
      assert.are.equal(600, cache.get_ttl())
    end)

    it("handles zero TTL (no expiry)", function()
      cache.set_ttl(0)
      assert.are.equal(0, cache.get_ttl())
    end)
  end)

  describe("size()", function()
    it("returns current cache size", function()
      assert.are.equal(0, cache.size())

      cache.set("key1", "value1")
      assert.are.equal(1, cache.size())

      cache.set("key2", "value2")
      assert.are.equal(2, cache.size())
    end)
  end)
end)
