---@module "lsp-overloads.settings"
local settings = require("lsp-overloads.settings")
---@module "lsp-overloads.handlers"
local handlers = require("lsp-overloads.handlers")

local M = {
  display_automatically = true,
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
  M.display_automatically = settings.current.display_automatically

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
      if (M.display_automatically) then
        local _, fwin = handlers.open_signature(clients, nil)
        M.open_fwin = fwin
      end
    end,
  })

  require("lsp-overloads.api.commands")
end


function M.show() --user requested show
  print("showing")
  local lsp_clients = vim.lsp.get_active_clients()
  if #lsp_clients < 1 then --quit here first so we dont have to create the table
    vim.notify("No LSP clients available")
    return false
  end

  local clients = {}
  for _, client in ipairs(lsp_clients) do
    if client.server_capabilities.signatureHelpProvider then
      table.insert(clients, client)
    end
  end
  if (#clients < 1) then 
    vim.notify("No LSP clients with signatureHelpProvider capabilities")
    return false 
  end
  
  handlers.open_signature(clients, true)
end
function M.visible()
  return M.open_fwin ~= nil
end
function M.toggle_display()
  if (M.visible()) then 
    M.hide()
  else 
    M.show()
  end
end
function M.hide()
  if (M.visible()) then
     vim.api.nvim_win_close(M.open_fwin,false)
     print("hidden")
     M.open_fwin = nil
  end
end

function M.toggle_automatic_display(explicitState,showOnToggle)
  local old = M.display_automatically
  if (explicitState == nil) then
    M.display_automatically = not M.display_automatically
  else
    M.display_automatically = explicitState
  end
  vim.notify("lsp overloads display automatically: "..tostring(M.display_automatically))
  --not sure if this is necessary anymore?
  if (not old and showOnToggle) then 
    M.show();
  end

  if (not M.display_automatically and M.visible()) then 
    M.hide()
  end
end


return M
