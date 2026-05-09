--- Tests for lsp-overloads._lsp.mappings

local mappings = require("lsp-overloads._lsp.mappings")
local configuration = require("lsp-overloads._core.configuration")

local function make_state(bufnr)
  return {
    bufnr = bufnr,
    mode = "i",
    fwin = nil,
    _buf_mappings = {},
    _original_mappings = {},
  }
end

describe("mappings", function()
  local bufnr

  before_each(function()
    configuration.reset()
    bufnr = vim.api.nvim_create_buf(false, true)
  end)

  after_each(function()
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end)

  describe("add()", function()
    it("creates a buffer-local keymap and tracks it", function()
      local state = make_state(bufnr)
      mappings.add(state, "test_map", "<C-t>", function(_) end)

      -- Verify the plugin tracked the mapping
      assert.equal("<C-t>", state._buf_mappings["test_map"])

      -- Verify the mapping actually exists in the buffer (maparg via buf_call)
      local found = vim.api.nvim_buf_call(bufnr, function()
        local m = vim.fn.maparg("<C-t>", "i", false, true)
        return m and m.lhs ~= nil
      end)
      assert.is_true(found)
    end)

    it("stores original mapping when one exists", function()
      -- Pre-create a buffer-local mapping to be overridden
      vim.keymap.set("i", "<C-t>", "original_rhs", { buffer = bufnr })

      local state = make_state(bufnr)
      mappings.add(state, "test_map", "<C-t>", function(_) end)

      assert.is_not_nil(state._original_mappings["<C-t>"])
    end)

    it("skips nil lhs", function()
      local state = make_state(bufnr)
      assert.has_no.errors(function()
        mappings.add(state, "test_map", nil, function(_) end)
      end)
      assert.same({}, state._buf_mappings)
    end)

    it("skips empty string lhs", function()
      local state = make_state(bufnr)
      assert.has_no.errors(function()
        mappings.add(state, "test_map", "", function(_) end)
      end)
      assert.same({}, state._buf_mappings)
    end)
  end)

  describe("remove()", function()
    it("deletes plugin-added mappings", function()
      local state = make_state(bufnr)
      mappings.add(state, "test_map", "<C-t>", function(_) end)

      mappings.remove(state)

      local buf_maps = vim.api.nvim_buf_get_keymap(bufnr, "i")
      local found = vim.iter(buf_maps):any(function(m)
        return m.lhs == "<C-t>"
      end)
      assert.is_false(found)
    end)

    it("restores original rhs-string mappings", function()
      vim.keymap.set("i", "<C-t>", "original_text", { buffer = bufnr })

      local state = make_state(bufnr)
      mappings.add(state, "test_map", "<C-t>", function(_) end)
      mappings.remove(state)

      -- Original mapping should be restored — verify via nvim_buf_call + maparg
      local rhs = vim.api.nvim_buf_call(bufnr, function()
        local m = vim.fn.maparg("<C-t>", "i", false, true)
        return m and m.rhs
      end)
      assert.equal("original_text", rhs)
    end)

    it("does not error when buffer is invalid", function()
      local state = make_state(9999)
      state._buf_mappings = { x = "<C-t>" }
      assert.has_no.errors(function()
        mappings.remove(state)
      end)
    end)

    it("clears _buf_mappings after removal", function()
      local state = make_state(bufnr)
      mappings.add(state, "m1", "<C-t>", function(_) end)
      mappings.remove(state)
      assert.same({}, state._buf_mappings)
    end)
  end)

  describe("setup()", function()
    it("installs all configured keymaps", function()
      local state = make_state(bufnr)
      local dummy = function(_, _) end
      mappings.setup(state, dummy, dummy)

      local km = configuration.current.keymaps
      local expected_keys = {
        km.next_signature,
        km.previous_signature,
        km.next_parameter,
        km.previous_parameter,
        km.close_signature,
        km.scroll_down,
        km.scroll_up,
      }
      -- Verify each expected keymap was tracked in state
      local registered = vim.tbl_values(state._buf_mappings)
      for _, lhs in ipairs(expected_keys) do
        local found = vim.tbl_contains(registered, lhs)
        assert.is_true(found, "expected keymap " .. lhs .. " to be registered in state._buf_mappings")
      end
    end)
  end)
end)
