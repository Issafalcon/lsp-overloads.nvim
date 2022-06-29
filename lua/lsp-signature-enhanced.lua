---@module "lsp-signature-enhanced.settings"
local settings = require("lsp-signature-enhanced.settings")
---@module "lsp-signature-enhanced.handler"
local signature = require("lsp-signature-enhanced.handler")
local M = {}

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local clients = {}

---@param config LspSignatureEnhancedSettings
function M.setup(client, config)
  if config then
    settings.set(config)
  end

  table.insert(clients, client)

  local group = augroup('LspSignature', { clear = false })
  vim.api.nvim_clear_autocmds({ group = group, pattern = '<buffer>' })
  autocmd('TextChangedI', {
    group = group,
    pattern = '<buffer>',
    callback = function()
      -- Guard against spamming of method not supported after
      -- stopping a language serer with LspStop
      local active_clients = vim.lsp.get_active_clients()
      if #active_clients < 1 then
        return
      end
      signature.open_signature(clients)
    end,
  })
end

return M
