--- Core Signature state model for lsp-overloads.nvim.
--- Manages the active overload index, parameter index, and popup lifecycle.

---@module "lsp-overloads.types"
---@module "lsp-overloads._core.configuration"
---@module "lsp-overloads._lsp.content"
---@module "lsp-overloads._lsp.mappings"

local configuration = require("lsp-overloads._core.configuration")
local content = require("lsp-overloads._lsp.content")
local mappings = require("lsp-overloads._lsp.mappings")

-- Buffer-variable key used to persist the user's manually-selected overload
local _ACTIVE_SIG_VAR = "lsp_overloads_active_sig"
-- Buffer-variable key used to suppress deletion of state during overload cycling
local _SWAPPING_VAR = "lsp_overloads_swapping"

local M = {}

--- Create a new SignatureState from a raw LSP signatureHelp response.
---
---@param result table Raw signatureHelp LSP result
---@param err any LSP error (usually nil)
---@param ctx table LSP context
---@param config table Options passed from the handler
---@return lsp-overloads.SignatureState
function M.new(result, err, ctx, config)
  local bufnr = vim.api.nvim_get_current_buf()
  local mode = vim.api.nvim_get_mode().mode

  -- Restore user's previously chosen overload index (fixes issue #52)
  local persisted_sig = vim.F.npcall(vim.api.nvim_buf_get_var, bufnr, _ACTIVE_SIG_VAR)

  local active_sig = result.activeSignature or 0
  if active_sig < 0 or active_sig >= #result.signatures then
    active_sig = 0
  end
  -- User's manual selection takes precedence over the server's suggestion
  if persisted_sig ~= nil and persisted_sig >= 0 and persisted_sig < #result.signatures then
    active_sig = persisted_sig
  end

  ---@type lsp-overloads.SignatureState
  local state = {
    signatures = result.signatures,
    activeSignature = active_sig,
    activeParameter = result.activeParameter,
    err = err,
    ctx = ctx,
    config = config,
    mode = mode,
    bufnr = bufnr,
    fwin = nil,
    fbuf = nil,
    content = {},
    _buf_mappings = {},
    _original_mappings = {},
  }

  return state
end

--- Move to the next or previous overload signature.
---
---@param state lsp-overloads.SignatureState
---@param sig_mod integer Positive = next, negative = previous
function M.modify_active_signature(state, sig_mod)
  if #state.signatures <= 1 then
    return
  end
  local next_idx = state.activeSignature + sig_mod
  if next_idx >= 0 and next_idx < #state.signatures then
    state.activeSignature = next_idx
    -- Persist the user's choice across new LSP responses
    vim.api.nvim_buf_set_var(state.bufnr, _ACTIVE_SIG_VAR, next_idx)
  end
end

--- Move to the next or previous parameter in the current signature.
---
---@param state lsp-overloads.SignatureState
---@param param_mod integer Positive = next, negative = previous
function M.modify_active_param(state, param_mod)
  local sig = state.signatures[state.activeSignature + 1]
  if not sig then
    return
  end

  -- Per-signature activeParameter takes precedence (LSP 3.17 spec)
  if sig.activeParameter ~= nil then
    local next_idx = sig.activeParameter + param_mod
    if next_idx >= 0 and sig.parameters and next_idx < #sig.parameters then
      sig.activeParameter = next_idx
    end
  elseif state.activeParameter ~= nil then
    local next_idx = state.activeParameter + param_mod
    if next_idx >= 0 and sig.parameters and next_idx < #sig.parameters then
      state.activeParameter = next_idx
    end
  elseif sig.parameters and #sig.parameters > 0 then
    -- Initialise when the server didn't send an activeParameter (some servers don't)
    sig.activeParameter = 0
    M.modify_active_param(state, param_mod)
  end
end

--- Open or refresh the signature popup window.
---
---@param state lsp-overloads.SignatureState
function M.open_popup(state)
  state.content = content.render(state)

  if not state.content.contents or vim.tbl_isempty(state.content.contents) then
    if not configuration.current.ui.silent then
      vim.notify("[lsp-overloads] No signature help available", vim.log.levels.INFO)
    end
    return
  end

  local cfg = vim.deepcopy(state.config)

  -- Apply z-index from configuration
  cfg.zindex = cfg.zindex or configuration.current.ui.zindex

  -- Attempt to place the popup above the cursor line if requested
  if configuration.current.ui.floating_window_above_cur_line then
    local popup_height = #state.content.contents
    local lines_above = vim.fn.winline() - 1
    local is_lower_half = lines_above > math.floor(vim.fn.winheight(0) / 2)
    if lines_above > popup_height and not is_lower_half then
      cfg.offset_y = (cfg.offset_y or 0) - popup_height - 3
    end
  end

  local fbuf, fwin = vim.lsp.util.open_floating_preview(state.content.contents, "markdown", cfg)

  if state.content.active_hl and fbuf then
    vim.api.nvim_buf_add_highlight(
      fbuf,
      -1,
      "LspSignatureActiveParameter",
      state.content.label_line,
      state.content.active_hl[1],
      state.content.active_hl[2]
    )
  end

  state.fbuf = fbuf
  state.fwin = fwin
end

--- Close the signature popup window.
---
---@param state lsp-overloads.SignatureState
function M.close_popup(state)
  if state.fwin and vim.api.nvim_win_is_valid(state.fwin) then
    vim.schedule(function()
      if vim.api.nvim_win_is_valid(state.fwin) then
        vim.api.nvim_win_close(state.fwin, true)
      end
    end)
  end
end

--- Cycle to a different overload or parameter and refresh the popup.
--- Called from keymap callbacks.
---
---@param state lsp-overloads.SignatureState
---@param opts {sig_modifier: integer, param_modifier: integer}
function M.cycle(state, opts)
  state.activeSignature = state.activeSignature or 0
  M.modify_active_signature(state, opts.sig_modifier or 0)
  M.modify_active_param(state, opts.param_modifier or 0)

  -- Signal that the popup is being replaced, not closed for good
  vim.api.nvim_buf_set_var(state.bufnr, _SWAPPING_VAR, state.fwin or -1)

  -- Reopen the popup with the updated active signature
  M.open_popup(state)

  -- Re-register autocommand for the new window
  require("lsp-overloads._lsp.autocommands").setup(state)
end

--- Clear the persisted overload selection for a buffer.
--- Called when the user leaves insert mode or the popup is closed without cycling.
---
---@param bufnr integer
function M.clear_persisted_selection(bufnr)
  vim.F.npcall(vim.api.nvim_buf_del_var, bufnr, _ACTIVE_SIG_VAR)
  vim.F.npcall(vim.api.nvim_buf_del_var, bufnr, _SWAPPING_VAR)
end

return M
