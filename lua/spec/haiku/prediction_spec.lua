-- Tests for haiku/prediction.lua

describe("prediction", function()
  local prediction

  before_each(function()
    package.loaded["haiku.prediction"] = nil
    prediction = require("haiku.prediction")
    prediction.clear()
  end)

  describe("record_edit()", function()
    it("stores edit in history", function()
      prediction.record_edit(
        { row = 1, col = 5 },
        { before = "old", after = "new" }
      )

      local stats = prediction.stats()
      assert.are.equal(1, stats.edit_count)
    end)

    it("limits history to max_edits", function()
      -- Record more than max_edits (50)
      for i = 1, 60 do
        prediction.record_edit(
          { row = i, col = 0 },
          { before = "", after = "x" }
        )
      end

      local stats = prediction.stats()
      assert.are.equal(50, stats.edit_count)
    end)
  end)

  describe("record_accept()", function()
    it("stores completion in history", function()
      prediction.record_accept({ type = "insert", text = "hello" })

      local stats = prediction.stats()
      assert.are.equal(1, stats.accept_count)
    end)

    it("limits history to max_accepts", function()
      -- Record more than max_accepts (10)
      for i = 1, 15 do
        prediction.record_accept({ type = "insert", text = tostring(i) })
      end

      local stats = prediction.stats()
      assert.are.equal(10, stats.accept_count)
    end)
  end)

  describe("get_recent_changes()", function()
    it("returns copy of edit history", function()
      prediction.record_edit(
        { row = 1, col = 0 },
        { before = "a", after = "b" }
      )

      local changes = prediction.get_recent_changes()

      assert.are.equal(1, #changes)
      assert.are.equal(1, changes[1].row)
      assert.are.equal("a", changes[1].before)
      assert.are.equal("b", changes[1].after)
    end)

    it("returns deep copy (modifications don't affect original)", function()
      prediction.record_edit(
        { row = 1, col = 0 },
        { before = "a", after = "b" }
      )

      local changes = prediction.get_recent_changes()
      changes[1].before = "modified"

      local changes2 = prediction.get_recent_changes()
      assert.are.equal("a", changes2[1].before)
    end)
  end)

  describe("predict_next()", function()
    it("returns nil with less than 2 edits", function()
      prediction.record_edit(
        { row = 1, col = 0 },
        { before = "", after = "x" }
      )

      local result = prediction.predict_next()
      assert.is_nil(result)
    end)

    it("detects vertical editing pattern", function()
      -- Two edits at same column, consecutive rows
      prediction.record_edit(
        { row = 5, col = 10 },
        { before = "", after = "x" }
      )
      prediction.record_edit(
        { row = 6, col = 10 },
        { before = "", after = "x" }
      )

      local result = prediction.predict_next()

      assert.is_not_nil(result)
      assert.are.equal(7, result.row)
      assert.are.equal(10, result.col)
    end)

    -- Note: repetitive replacement pattern test requires buffer mocking
    -- which is complex. The vertical editing test covers the basic pattern detection.
  end)

  describe("predict_positions_in_completion()", function()
    it("detects empty function call ()", function()
      local positions = prediction.predict_positions_in_completion({
        text = "foo()"
      })

      local found = false
      for _, pos in ipairs(positions) do
        if pos.type == "function_args" then
          found = true
          assert.are.equal("Add arguments", pos.hint)
          break
        end
      end
      assert.is_true(found)
    end)

    it("detects empty double-quoted string", function()
      local positions = prediction.predict_positions_in_completion({
        text = 'x = ""'
      })

      local found = false
      for _, pos in ipairs(positions) do
        if pos.type == "string_content" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it("detects empty single-quoted string", function()
      local positions = prediction.predict_positions_in_completion({
        text = "x = ''"
      })

      local found = false
      for _, pos in ipairs(positions) do
        if pos.type == "string_content" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it("detects empty array []", function()
      local positions = prediction.predict_positions_in_completion({
        text = "arr = []"
      })

      local found = false
      for _, pos in ipairs(positions) do
        if pos.type == "array_content" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it("detects empty object {}", function()
      local positions = prediction.predict_positions_in_completion({
        text = "obj = {}"
      })

      local found = false
      for _, pos in ipairs(positions) do
        if pos.type == "object_content" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it("always includes end position", function()
      local positions = prediction.predict_positions_in_completion({
        text = "hello"
      })

      local found = false
      for _, pos in ipairs(positions) do
        if pos.type == "end" then
          found = true
          assert.are.equal(5, pos.offset)
          break
        end
      end
      assert.is_true(found)
    end)

    it("handles empty text", function()
      local positions = prediction.predict_positions_in_completion({
        text = ""
      })

      assert.are.equal(0, #positions)
    end)

    it("handles nil text", function()
      local positions = prediction.predict_positions_in_completion({})

      assert.are.equal(0, #positions)
    end)

    it("uses insert field as fallback", function()
      local positions = prediction.predict_positions_in_completion({
        insert = "foo()"
      })

      local found = false
      for _, pos in ipairs(positions) do
        if pos.type == "function_args" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)
  end)

  describe("clear()", function()
    it("clears all history", function()
      prediction.record_edit({ row = 1, col = 0 }, { before = "", after = "x" })
      prediction.record_accept({ type = "insert", text = "y" })

      prediction.clear()

      local stats = prediction.stats()
      assert.are.equal(0, stats.edit_count)
      assert.are.equal(0, stats.accept_count)
    end)
  end)

  describe("stats()", function()
    it("returns correct counts", function()
      prediction.record_edit({ row = 1, col = 0 }, { before = "", after = "x" })
      prediction.record_edit({ row = 2, col = 0 }, { before = "", after = "y" })
      prediction.record_accept({ type = "insert", text = "z" })

      local stats = prediction.stats()

      assert.are.equal(2, stats.edit_count)
      assert.are.equal(1, stats.accept_count)
      assert.are.equal(50, stats.max_edits)
      assert.are.equal(10, stats.max_accepts)
    end)
  end)
end)
