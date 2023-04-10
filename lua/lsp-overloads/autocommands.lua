local M = {}

function M.setup_signature_augroup(signature)
  local bufnr = signature.bufnr
  local fwin = signature.fwin
  local augroup = vim.api.nvim_create_augroup("LspSignature_popup_" .. fwin, { clear = false })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    pattern = tostring(fwin),
    callback = function()
      -- If the window was closed during a cycling of the signature or the signature param,
      -- then the 'is_swapping_overload' variable will have been set. If it wasn't closed this way, we can delete the signature object.
      local overload_swapping = vim.F.npcall(vim.api.nvim_buf_get_var, bufnr, "is_swapping_overload")
      if not overload_swapping or not vim.api.nvim_win_is_valid(overload_swapping) then
        signature:remove_mappings(bufnr, signature.mode)
        signature = nil
      end

      vim.api.nvim_del_augroup_by_id(augroup)
    end,
  })
end

return M
