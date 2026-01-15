-- Tests for haiku/util.lua

describe("util", function()
  local util

  before_each(function()
    package.loaded["haiku.util"] = nil
    util = require("haiku.util")
  end)

  describe("tbl_contains()", function()
    it("returns true when value exists", function()
      local tbl = { "a", "b", "c" }
      assert.is_true(util.tbl_contains(tbl, "b"))
    end)

    it("returns false when value missing", function()
      local tbl = { "a", "b", "c" }
      assert.is_false(util.tbl_contains(tbl, "d"))
    end)

    it("returns false for empty table", function()
      assert.is_false(util.tbl_contains({}, "a"))
    end)

    it("handles numeric values", function()
      local tbl = { 1, 2, 3 }
      assert.is_true(util.tbl_contains(tbl, 2))
      assert.is_false(util.tbl_contains(tbl, 4))
    end)
  end)

  describe("split()", function()
    it("splits string by delimiter", function()
      local result = util.split("a,b,c", ",")
      assert.are.same({ "a", "b", "c" }, result)
    end)

    it("handles single element", function()
      local result = util.split("abc", ",")
      assert.are.same({ "abc" }, result)
    end)

    it("handles different delimiters", function()
      local result = util.split("a:b:c", ":")
      assert.are.same({ "a", "b", "c" }, result)
    end)

    it("skips empty parts", function()
      local result = util.split("a,,b", ",")
      -- The current implementation skips empty parts due to pattern matching
      assert.are.same({ "a", "b" }, result)
    end)

    it("handles empty string input", function()
      local result = util.split("", ",")
      assert.are.same({}, result)
    end)

    it("handles no delimiter matches", function()
      local result = util.split("abc", "x")
      assert.are.same({ "abc" }, result)
    end)
  end)

  describe("id_generator()", function()
    it("returns incrementing IDs", function()
      local gen = util.id_generator()

      assert.are.equal(1, gen())
      assert.are.equal(2, gen())
      assert.are.equal(3, gen())
    end)

    it("creates independent generators", function()
      local gen1 = util.id_generator()
      local gen2 = util.id_generator()

      assert.are.equal(1, gen1())
      assert.are.equal(1, gen2())
      assert.are.equal(2, gen1())
      assert.are.equal(2, gen2())
    end)
  end)

  describe("now()", function()
    it("returns a number", function()
      local time = util.now()
      assert.is_number(time)
    end)

    it("returns non-decreasing values", function()
      local t1 = util.now()
      local t2 = util.now()

      assert.is_true(t2 >= t1)
    end)
  end)

  describe("tbl_deep_extend()", function()
    it("merges tables", function()
      local t1 = { a = 1 }
      local t2 = { b = 2 }
      local result = util.tbl_deep_extend(t1, t2)

      assert.are.equal(1, result.a)
      assert.are.equal(2, result.b)
    end)

    it("deep merges nested tables", function()
      local t1 = { outer = { inner = 1 } }
      local t2 = { outer = { other = 2 } }
      local result = util.tbl_deep_extend(t1, t2)

      assert.are.equal(1, result.outer.inner)
      assert.are.equal(2, result.outer.other)
    end)

    it("overrides with later values", function()
      local t1 = { a = 1 }
      local t2 = { a = 2 }
      local result = util.tbl_deep_extend(t1, t2)

      assert.are.equal(2, result.a)
    end)
  end)

  describe("pcall_wrap()", function()
    it("returns true and result on success", function()
      local ok, result = util.pcall_wrap(function()
        return 42
      end)

      assert.is_true(ok)
      assert.are.equal(42, result)
    end)

    it("returns false and error on failure", function()
      local ok, err = util.pcall_wrap(function()
        error("test error")
      end)

      assert.is_false(ok)
      assert.is_string(err)
    end)

    it("passes arguments to function", function()
      local ok, result = util.pcall_wrap(function(a, b)
        return a + b
      end, 10, 20)

      assert.is_true(ok)
      assert.are.equal(30, result)
    end)
  end)

  describe("cleanup_timer()", function()
    it("handles nil timer gracefully", function()
      -- Should not error
      util.cleanup_timer(nil)
    end)

    it("stops and closes valid timer", function()
      local timer = vim.uv.new_timer()
      timer:start(1000, 0, function() end)

      util.cleanup_timer(timer)

      -- Timer should be stopped (can't easily verify, but no error is good)
    end)
  end)

  describe("debounce_trailing()", function()
    it("returns a function and timer", function()
      local debounced, timer = util.debounce_trailing(function() end, 100)

      assert.is_function(debounced)
      assert.is_userdata(timer)

      util.cleanup_timer(timer)
    end)

    it("does not call immediately", function()
      local called = false
      local debounced, timer = util.debounce_trailing(function()
        called = true
      end, 100)

      debounced()

      assert.is_false(called)

      util.cleanup_timer(timer)
    end)
  end)

  describe("debounce_leading()", function()
    it("calls immediately on first invocation", function()
      local called = false
      local debounced, timer = util.debounce_leading(function()
        called = true
      end, 100)

      debounced()

      assert.is_true(called)

      util.cleanup_timer(timer)
    end)

    it("blocks subsequent calls within cooldown", function()
      local call_count = 0
      local debounced, timer = util.debounce_leading(function()
        call_count = call_count + 1
      end, 100)

      debounced()
      debounced()
      debounced()

      assert.are.equal(1, call_count)

      util.cleanup_timer(timer)
    end)
  end)

  describe("throttle()", function()
    it("returns a function and timer", function()
      local throttled, timer = util.throttle(function() end, 100)

      assert.is_function(throttled)
      assert.is_userdata(timer)

      util.cleanup_timer(timer)
    end)

    it("calls immediately on first invocation", function()
      local called = false
      local throttled, timer = util.throttle(function()
        called = true
      end, 100)

      throttled()

      assert.is_true(called)

      util.cleanup_timer(timer)
    end)
  end)
end)
