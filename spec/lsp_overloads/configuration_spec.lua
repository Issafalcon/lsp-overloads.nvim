--- Tests for lsp-overloads._core.configuration

local configuration = require("lsp-overloads._core.configuration")

describe("configuration", function()
  before_each(function()
    configuration.reset()
  end)

  describe("defaults", function()
    it("provides default keymaps", function()
      local defaults = configuration.defaults()
      assert.equal("<C-j>", defaults.keymaps.next_signature)
      assert.equal("<C-k>", defaults.keymaps.previous_signature)
      assert.equal("<C-l>", defaults.keymaps.next_parameter)
      assert.equal("<C-h>", defaults.keymaps.previous_parameter)
      assert.equal("<A-s>", defaults.keymaps.close_signature)
      assert.equal("<C-d>", defaults.keymaps.scroll_down)
      assert.equal("<C-u>", defaults.keymaps.scroll_up)
    end)

    it("has display_automatically enabled by default", function()
      assert.is_true(configuration.defaults().display_automatically)
    end)

    it("has override_native_handler enabled by default", function()
      assert.is_true(configuration.defaults().override_native_handler)
    end)

    it("has silent ui by default", function()
      assert.is_true(configuration.defaults().ui.silent)
    end)

    it("has a default border", function()
      assert.equal("single", configuration.defaults().ui.border)
    end)

    it("has a default zindex", function()
      assert.equal(50, configuration.defaults().ui.zindex)
    end)
  end)

  describe("set()", function()
    it("merges user options with defaults", function()
      configuration.set({ ui = { border = "rounded" } })
      assert.equal("rounded", configuration.current.ui.border)
      -- Other ui fields are still defaults
      assert.is_true(configuration.current.ui.silent)
    end)

    it("deep-merges nested tables", function()
      configuration.set({ keymaps = { next_signature = "<M-j>" } })
      assert.equal("<M-j>", configuration.current.keymaps.next_signature)
      -- Other keymaps untouched
      assert.equal("<C-k>", configuration.current.keymaps.previous_signature)
    end)

    it("can disable display_automatically", function()
      configuration.set({ display_automatically = false })
      assert.is_false(configuration.current.display_automatically)
    end)

    it("can disable override_native_handler", function()
      configuration.set({ override_native_handler = false })
      assert.is_false(configuration.current.override_native_handler)
    end)

    it("can be called multiple times and accumulates changes", function()
      configuration.set({ ui = { border = "double" } })
      configuration.set({ ui = { zindex = 100 } })
      assert.equal("double", configuration.current.ui.border)
      assert.equal(100, configuration.current.ui.zindex)
    end)
  end)

  describe("reset()", function()
    it("restores defaults after set()", function()
      configuration.set({ ui = { border = "none" }, display_automatically = false })
      configuration.reset()
      assert.equal("single", configuration.current.ui.border)
      assert.is_true(configuration.current.display_automatically)
    end)

    it("clears the loaded guard flag", function()
      vim.g.loaded_lsp_overloads = true
      configuration.reset()
      assert.is_false(vim.g.loaded_lsp_overloads)
    end)
  end)

  describe("initialize_if_needed()", function()
    it("only runs once per session (guard flag)", function()
      -- First call initialises
      configuration.initialize_if_needed()
      assert.is_true(vim.g.loaded_lsp_overloads)
      -- Second call is a no-op
      vim.g.lsp_overloads_config = { ui = { border = "double" } }
      configuration.initialize_if_needed()
      -- border should still be single (second call skipped)
      assert.equal("single", configuration.current.ui.border)
      vim.g.lsp_overloads_config = nil
    end)
  end)
end)
