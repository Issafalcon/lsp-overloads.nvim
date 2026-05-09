--- lsp-overloads.nvim public API.
--- Provides setup(), on_attach(), and the raw LSP handler.

---@module "lsp-overloads.types"

local M = {}

--- Configure lsp-overloads.nvim.
--- Call once in your Neovim config, before or after your LSP setup.
---
--- When `override_native_handler` is true (the default), the plugin installs
--- itself as the global textDocument/signatureHelp handler so that Neovim and
--- any other plugin that calls vim.lsp.buf.signature_help() will use
--- lsp-overloads instead of the built-in handler.
---
---@param opts lsp-overloads.Config?  Partial configuration — merged with defaults
function M.setup(opts)
  local configuration = require("lsp-overloads._core.configuration")
  configuration.initialize_if_needed()
  if opts then
    configuration.set(opts)
  end

  -- Apply active-parameter highlight if the user specified one
  local hl = configuration.current.ui.highlight
  if hl then
    vim.api.nvim_set_hl(0, "LspSignatureActiveParameter", hl)
  end

  -- Override the native handler globally so only lsp-overloads renders popups
  if configuration.current.override_native_handler then
    local handler = require("lsp-overloads._lsp.handler")
    vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(handler.handler, {
      border = configuration.current.ui.border,
      silent = configuration.current.ui.silent,
      close_events = configuration.current.ui.close_events,
      focusable = configuration.current.ui.focusable,
      focus = configuration.current.ui.focus,
    })
  end

  -- Auto-attach to every LSP client that supports signatureHelp
  local autocommands = require("lsp-overloads._lsp.autocommands")
  autocommands.setup_lsp_attach(function(client, bufnr)
    M.on_attach(client, bufnr)
  end)
end

--- Attach lsp-overloads to a specific LSP client on a buffer.
--- Use this inside your lspconfig / vim.lsp.config on_attach callback when
--- you want fine-grained control over which clients are supported.
---
---@param client vim.lsp.Client
---@param bufnr integer
function M.on_attach(client, bufnr)
  if not vim.tbl_get(client, "server_capabilities", "signatureHelpProvider") then
    return
  end

  local handler = require("lsp-overloads._lsp.handler")
  local autocommands = require("lsp-overloads._lsp.autocommands")

  autocommands.setup_text_change(bufnr, function()
    handler.open_signature(false)
  end)
end

--- The raw LSP handler function.
--- Can be used to manually install the handler, e.g.:
---   vim.lsp.handlers["textDocument/signatureHelp"] = require("lsp-overloads").handler
---@type fun(err: any, result: table?, ctx: table, config: table)
M.handler = require("lsp-overloads._lsp.handler").handler

return M
