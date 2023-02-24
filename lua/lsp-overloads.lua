---@module "lsp-overloads.settings"
local settings = require("lsp-overloads.settings")
---@module "lsp-overloads.handlers"
local handlers = require("lsp-overloads.handlers")

local M = {
  enabled = true,
  open_fwin=nil
}

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local clients = {}

---@param config LspOverloadsSettings The settings for the lsp-overload plugin
---@param client any The |vim.lsp.client| instance to extend the handlers for
function M.setup(client, config)
  if config then
    settings.set(config)
  end
  M.enabled = settings.current.enabled_by_default

  table.insert(clients, client)
  local group = augroup("LspSignature", { clear = false })
  vim.api.nvim_clear_autocmds({ group = group, pattern = "<buffer>" })
  autocmd("TextChangedI", {
    group = group,
    pattern = "<buffer>",
    callback = function()
      -- Guard against spamming of method not supported after
      -- stopping a language server with LspStop
      local active_clients = vim.lsp.get_active_clients()
      if #active_clients < 1 then
        return
      end
      if (M.enabled) then
        local _, fwin = handlers.open_signature(clients, nil)
        M.open_fwin = fwin
      end
    end,
  })

  require("lsp-overloads.api.commands")
end


function M.user_request_overloads_signature()
  local lsp_clients = vim.lsp.get_active_clients()
  if #lsp_clients < 1 then --quit here first so we dont have to create the table
    return false
  end

  local clients = {}
  for _, client in ipairs(lsp_clients) do
    if client.server_capabilities.signatureHelpProvider then
      table.insert(clients, client)
    end
  end
  if (#clients < 1) then 
    return false 
  end
  
  local _, fwin = handlers.open_signature(clients, true)
  M.open_fwin = fwin
end

M.toggle = function(explicitState,showOnToggle)
  local old = M.enabled
  if (explicitState == nil) then
    M.enabled = not M.enabled
  else
    M.enabled = explicitState
  end
  vim.notify("lsp overloads enabled: "..tostring(M.enabled))
  if (not old and showOnToggle) then 
    M.user_request_overloads_signature();
  end

  if (not M.enabled and M.open_fwin) then 
    vim.api.nvim_win_close(m.open_fwin)
    M.open_fwin = nil
  end
end

return M
