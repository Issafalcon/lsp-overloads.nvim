--- Autocommand setup for lsp-overloads.nvim popup lifecycle.

---@module "lsp-overloads.types"

local M = {}

--- Set up the WinClosed autocommand for a signature popup window.
--- When the floating window is closed (by anything other than overload cycling),
--- keymaps are removed and the persisted overload selection is cleared.
---
---@param state lsp-overloads.SignatureState
function M.setup(state)
  if not state.fwin then
    return
  end

  local bufnr = state.bufnr
  local fwin = state.fwin
  local group_name = "LspOverloadsPopup_" .. fwin
  local group = vim.api.nvim_create_augroup(group_name, { clear = true })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(fwin),
    once = true,
    callback = function()
      -- Check if the popup is being closed because the user is cycling overloads.
      -- If so, don't clean up — the new popup will take over.
      local swapping = vim.F.npcall(vim.api.nvim_buf_get_var, bufnr, "lsp_overloads_swapping")
      local is_cycling = swapping ~= nil and swapping == fwin

      -- Guard against the async case: if open_floating_preview already closed
      -- this window and created a newer replacement, the lsp_floating_preview
      -- buffer variable will point to a *different* (still-valid) window.
      -- Removing keymaps in that situation would strip the new popup's bindings.
      local current_lsp_float = vim.F.npcall(vim.api.nvim_buf_get_var, bufnr, "lsp_floating_preview")
      local has_newer_float = current_lsp_float
        and vim.api.nvim_win_is_valid(current_lsp_float)
        and current_lsp_float ~= fwin

      if not is_cycling and not has_newer_float then
        local sig_mod = require("lsp-overloads._lsp.signature")
        local map_mod = require("lsp-overloads._lsp.mappings")
        map_mod.remove(state)
        sig_mod.clear_persisted_selection(bufnr)
      else
        -- Clear the swapping flag now that the old window is gone
        vim.F.npcall(vim.api.nvim_buf_del_var, bufnr, "lsp_overloads_swapping")
      end

      -- Always clean up the augroup itself
      vim.F.npcall(vim.api.nvim_del_augroup_by_id, group)
    end,
  })
end

--- Register a LspAttach autocmd to auto-attach lsp-overloads to new LSP clients.
--- Only clients that support signatureHelp are attached.
---
---@param on_attach fun(client: vim.lsp.Client, bufnr: integer)
function M.setup_lsp_attach(on_attach)
  local group = vim.api.nvim_create_augroup("LspOverloadsAttach", { clear = true })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client then
        return
      end
      if not vim.tbl_get(client, "server_capabilities", "signatureHelpProvider") then
        return
      end
      on_attach(client, args.buf)
    end,
  })
end

--- Register a TextChangedI autocmd on the current buffer to auto-trigger signature help.
---
---@param bufnr integer
---@param trigger_fn fun()
function M.setup_text_change(bufnr, trigger_fn)
  local group = vim.api.nvim_create_augroup("LspOverloadsSignature_" .. bufnr, { clear = true })
  vim.api.nvim_create_autocmd("TextChangedI", {
    group = group,
    buffer = bufnr,
    callback = function()
      local cfg = require("lsp-overloads._core.configuration")
      if cfg.current.display_automatically then
        local clients = vim.lsp.get_clients({ bufnr = bufnr })
        if #clients > 0 then
          trigger_fn()
        end
      end
    end,
  })

  -- Clean up the autocmd when the buffer is detached from its last LSP client
  vim.api.nvim_create_autocmd("LspDetach", {
    group = group,
    buffer = bufnr,
    callback = function()
      pcall(vim.api.nvim_del_augroup_by_id, group)
    end,
  })
end

return M
