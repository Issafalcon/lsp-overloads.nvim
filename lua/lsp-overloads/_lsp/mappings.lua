--- Buffer-local keymap management for lsp-overloads.nvim.
--- Adds plugin keymaps while the signature popup is open,
--- restores original keymaps when the popup closes.

---@module "lsp-overloads.types"
---@module "lsp-overloads._core.configuration"

local configuration = require("lsp-overloads._core.configuration")

local M = {}

-- The mode used for all signature-navigation keymaps.
-- Insert mode is the primary context: the user is typing arguments.
local _KEYMAP_MODE = "i"

--- Add a buffer-local keymap for signature navigation.
--- Stores the original keymap so it can be restored on popup close.
---
--- NOTE: We deliberately avoid `expr = true` here — the original implementation
--- used expr mappings that returned nil, causing them to be unreliable across
--- modes.  Plain buffer-local mappings work correctly everywhere.
---
---@param state lsp-overloads.SignatureState
---@param map_name string Logical name key (e.g. "sig_next")
---@param lhs string? The key sequence to bind (nil = skip)
---@param rhs fun(state: lsp-overloads.SignatureState) The callback
function M.add(state, map_name, lhs, rhs)
  if not lhs or lhs == "" then
    return
  end

  local bufnr = state.bufnr

  -- Save original mapping so we can restore it later
  if state._original_mappings[lhs] == nil then
    -- Use nvim_buf_call to ensure buffer-local mappings are found correctly
    local existing = vim.api.nvim_buf_call(bufnr, function()
      return vim.fn.maparg(lhs, _KEYMAP_MODE, false, true)
    end)
    if existing and existing.lhs then
      state._original_mappings[lhs] = existing
    end
  end

  vim.keymap.set(_KEYMAP_MODE, lhs, function()
    rhs(state)
  end, { buffer = bufnr, nowait = true, silent = true, desc = "lsp-overloads: " .. map_name })

  state._buf_mappings[map_name] = lhs
end

--- Remove all plugin-added keymaps and restore the user's original bindings.
---
---@param state lsp-overloads.SignatureState
function M.remove(state)
  local bufnr = state.bufnr

  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    state._buf_mappings = {}
    state._original_mappings = {}
    return
  end

  for _, lhs in pairs(state._buf_mappings) do
    -- Remove the plugin's mapping (silently, to guard against race conditions)
    pcall(vim.keymap.del, _KEYMAP_MODE, lhs, { buffer = bufnr })

    -- Restore the original mapping if one was saved
    local original = state._original_mappings[lhs]
    if original and original.lhs then
      -- Reconstruct the mapping from the saved maparg() dict
      local restore_opts = {
        buffer = bufnr,
        silent = original.silent == 1,
        nowait = original.nowait == 1,
        expr = original.expr == 1,
        noremap = original.noremap == 1,
      }
      local callback = original.callback
      if callback then
        vim.keymap.set(original.mode or _KEYMAP_MODE, original.lhs, callback, restore_opts)
      elseif original.rhs and original.rhs ~= "" then
        vim.keymap.set(original.mode or _KEYMAP_MODE, original.lhs, original.rhs, restore_opts)
      end
      state._original_mappings[lhs] = nil
    end
  end

  state._buf_mappings = {}
end

--- Install all signature navigation keymaps for a given state.
---
---@param state lsp-overloads.SignatureState
---@param modify_fn fun(state: lsp-overloads.SignatureState, opts: table) Signature modifier callback
---@param close_fn fun(state: lsp-overloads.SignatureState) Close callback
function M.setup(state, modify_fn, close_fn)
  local km = configuration.current.keymaps

  -- Cycle overloads/parameters directly (no timer): calling modify_fn
  -- synchronously from insert mode is safe and avoids the timer race
  -- where the popup could close between keypress and deferred callback.
  M.add(state, "sig_next", km.next_signature, function(s)
    modify_fn(s, { sig_modifier = 1, param_modifier = 0 })
  end)

  M.add(state, "sig_prev", km.previous_signature, function(s)
    modify_fn(s, { sig_modifier = -1, param_modifier = 0 })
  end)

  M.add(state, "param_next", km.next_parameter, function(s)
    modify_fn(s, { sig_modifier = 0, param_modifier = 1 })
  end)

  M.add(state, "param_prev", km.previous_parameter, function(s)
    modify_fn(s, { sig_modifier = 0, param_modifier = -1 })
  end)

  M.add(state, "close", km.close_signature, function(s)
    close_fn(s)
  end)

  -- Scroll the floating window.  nvim_win_call makes fwin the active window
  -- for the duration of the callback so :normal! operates on the float.
  -- "\4" and "\21" are the literal Ctrl-D / Ctrl-U control characters that
  -- :normal! requires (string key names like "<C-d>" are NOT expanded there).
  M.add(state, "scroll_down", km.scroll_down, function(s)
    if s.fwin and vim.api.nvim_win_is_valid(s.fwin) then
      local count = math.max(1, math.floor(vim.api.nvim_win_get_height(s.fwin) / 2))
      vim.api.nvim_win_call(s.fwin, function()
        vim.cmd("normal! " .. count .. "\4")
      end)
    end
  end)

  M.add(state, "scroll_up", km.scroll_up, function(s)
    if s.fwin and vim.api.nvim_win_is_valid(s.fwin) then
      local count = math.max(1, math.floor(vim.api.nvim_win_get_height(s.fwin) / 2))
      vim.api.nvim_win_call(s.fwin, function()
        vim.cmd("normal! " .. count .. "\21")
      end)
    end
  end)
end

return M
