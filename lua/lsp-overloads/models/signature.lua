---@module "lsp-overloads.models.signature-content"
local SignatureContent = require("lsp-overloads.models.signature-content")

---@class Signature
local Signature = {
  signatures = {},
  activeSignature = nil,
  activeParameter = nil,
  err = {},
  ctx = {},
  config = {},
  mappings = {},
  original_buf_mappings = {},
  bufnr = nil,
  fwin = nil,
  signature_content = SignatureContent:new(),
}

function Signature:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self

  return o
end

function Signature:update_with_lsp_response(err, ctx, config)
  self.err = err
  self.mode = vim.api.nvim_get_mode()["mode"]
  self.ctx = ctx
  self.config = config
end
--- Checks the current active signature exists. If it does,
-- moves to the next or previous signature in the list (without going out of bounds).
---@param sig_mod? number Negative to move to the previous signature, positive to move to the next signature. Defaults to 0
function Signature:modify_active_signature(sig_mod)
  if #self.signatures == 1 then
    return
  else
    local next_possible_sig_idx = self.activeSignature + (sig_mod or 0)
    if next_possible_sig_idx >= 0 and #self.signatures - 1 >= next_possible_sig_idx then
      self.activeSignature = next_possible_sig_idx
    end
  end
end

--- Checks the current active signature exists. If it does,
-- moves to the next or previous parameter in the signature (without going out of bounds).
---@param param_mod? number Negative to move to the previous parameter, positive to move to the next parameter. Defaults to 0
function Signature:modify_active_param(param_mod)
  local current_sig_index = self.activeSignature + 1

  if self.activeParameter then
    local next_possible_param_idx = self.activeParameter + (param_mod or 0)

    if
      next_possible_param_idx >= 0
      and self.signatures[current_sig_index] ~= nil
      and (#self.signatures[current_sig_index].parameters - 1) >= next_possible_param_idx
    then
      self.activeParameter = next_possible_param_idx
    end
  else
    local next_possible_param_idx = self.signatures[current_sig_index].activeParameter + (param_mod or 0)
    if
      next_possible_param_idx >= 0
      and (#self.signatures[current_sig_index].parameters - 1) >= next_possible_param_idx
    then
      self.signatures[current_sig_index].activeParameter = next_possible_param_idx
    end
  end
end

function Signature:add_mapping(mapName, default_lhs, rhs, opts)
  if self.mappings[self.bufnr] == nil then
    self.mappings[self.bufnr] = {}
  end

  if self.original_buf_mappings[self.bufnr] == nil then
    self.original_buf_mappings[self.bufnr] = {}
  end

  local config_lhs = self.mappings[self.bufnr][mapName] or default_lhs

  if config_lhs == nil then
    return
  end

  -- Check if we have already stored the users original keymapping value before
  -- If we haven't, get it from the list of buf keymaps and store it, so that when the signature window is destroyed later,
  -- we can restore the users original keymapping.
  if self.original_buf_mappings[self.bufnr][config_lhs] == nil and vim.fn.mapcheck(config_lhs, self.mode) ~= "" then
    local original_map = vim.fn.maparg(config_lhs, self.mode, 0, 1)
    self.original_buf_mappings[self.bufnr][config_lhs] = original_map
  end

  vim.keymap.set(self.mode, config_lhs, function()
    rhs(opts)
  end, { buffer = self.bufnr, expr = true, nowait = true })

  self.mappings[self.bufnr][mapName] = config_lhs
end

function Signature:remove_mappings(bufnr, mode)
  for _, buf_local_mappings in pairs(self.mappings) do
    for _, lhs in pairs(buf_local_mappings) do
      -- Delete the mapping if it has been created (this may error in the case of race conditions, so swallow it)
      pcall(vim.keymap.del, mode, lhs, { buffer = bufnr, silent = true })

      -- Restore the original mapping if it existed
      local original_buf_map = self.original_buf_mappings[bufnr][lhs]

      if original_buf_map ~= nil then
        vim.fn.mapset(self.mode, 0, original_buf_map)
        self.original_buf_mappings[bufnr][lhs] = nil
      end
    end
  end

  self.mappings = {}
end

function Signature:create_signature_popup()
  self.signature_content:add_content(self)

  -- Try and place the floating window above the cursor. If there is not enough room,
  -- fallback to the default behaviour of nvim_open_win
  if self.config.floating_window_above_cur_line then
    local _, height = vim.lsp.util._make_floating_popup_size(self.signature_content.contents, self.config)

    local lines_above = vim.fn.winline() - 1
    local is_lower_win_half = lines_above > math.floor(vim.fn.winheight(0) / 2)

    -- If the cursor is in the lower half of the window,
    -- the standard functionality will already offset the popup to be above the cursor, so we don't neeed to do it again.
    if lines_above > height and not is_lower_win_half then
      self.config.offset_y = -height - 3 -- -3 brings the bottom of the popup above the current line
    end
  end

  -- This will replace the existing lsp signature popup if it existsk with a new one.
  -- so keep track of new buffer and win numbers
  local fbuf, fwin = vim.lsp.util.open_floating_preview(self.signature_content.contents, "markdown", self.config)
  if self.signature_content.active_hl then
    vim.api.nvim_buf_add_highlight(fbuf, -1, "LspSignatureActiveParameter", 0, unpack(self.signature_content.active_hl))
  end
  local bufnr = vim.api.nvim_get_current_buf()

  self.bufnr = bufnr
  self.fwin = fwin
end

function Signature:close_signature_popup()
  -- Close the window here, which will trigger the autocommand to remove the mappings and dispose of the signature object
  vim.schedule(function()
    vim.api.nvim_win_close(self.fwin, true)
  end)
end

return Signature
