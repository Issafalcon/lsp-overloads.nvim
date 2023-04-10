---@module "lsp-overloads.settings"
local settings = require("lsp-overloads.settings")
---@module "lsp-overloads.handlers"
local handlers = require("lsp-overloads.handlers")

local M = {}

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local clients = {}

---@param config LspOverloadsSettings The settings for the lsp-overload plugin
---@param client any The |vim.lsp.client| instance to extend the handlers for
function M.setup(client, config)
  if config then
    settings.set(config)
  end

  table.insert(clients, client)

  local group = augroup("LspSignature", { clear = false })
  vim.api.nvim_clear_autocmds({ group = group, pattern = "<buffer>" })
  autocmd("TextChangedI", {
    group = group,
    pattern = "<buffer>",
    callback = function()
      -- Guard against spamming of method not supported after
      -- stopping a language server with LspStop
      if settings.current.display_automatically then
        local active_clients = vim.lsp.get_active_clients()
        if #active_clients < 1 then
          return
        end
        handlers.open_signature(clients)
      end
    end,
  })

  require("lsp-overloads.api.commands")
end

return M
