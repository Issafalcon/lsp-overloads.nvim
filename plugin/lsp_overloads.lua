--- lsp-overloads.nvim plugin entry point.
--- This file is auto-sourced by Neovim from the plugin/ directory.
--- It registers the :LspOverloads user command and installs the native handler
--- override (if configured).  All actual logic is lazily loaded.

-- Prevent double-sourcing
if vim.g.loaded_lsp_overloads_plugin then
  return
end
vim.g.loaded_lsp_overloads_plugin = true

local cmdparse = require("lsp-overloads._core.cmdparse")

---@type table<string, lsp-overloads.Subcommand>
local subcommands = {
  signature = {
    impl = function(_, _)
      local handler = require("lsp-overloads._lsp.handler")
      handler.open_signature(true)
    end,
  },
  toggle = {
    impl = function(_, _)
      local configuration = require("lsp-overloads._core.configuration")
      configuration.current.display_automatically = not configuration.current.display_automatically
      local state = configuration.current.display_automatically and "enabled" or "disabled"
      vim.notify("[lsp-overloads] Auto-display " .. state, vim.log.levels.INFO)
    end,
  },
}

cmdparse.create("LspOverloads", subcommands, {
  desc = "lsp-overloads.nvim commands",
})
