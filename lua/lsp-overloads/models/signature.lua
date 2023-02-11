local SignatureContent = require("lsp-overloads.models.signature-content")

local Signature = {
  signatures = {},
  activeSignature = nil,
  activeParameter = nil,
  err = {},
  ctx = {},
  config = {},
  mappings = {},
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

function Signature:update_with_lsp_response(err, result, ctx, config)
  self = vim.tbl_deep_extend("force", self, result)
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

function Signature:add_mapping(bufnr, mode, mapName, default_lhs, rhs, opts)
  if self.mappings[bufnr] == nil then
    self.mappings[bufnr] = {}
  end

  local config_lhs = self.mappings[bufnr][mapName] or default_lhs
  if config_lhs == nil then
    return
  end

  vim.keymap.set(mode, config_lhs, function()
    rhs(opts)
  end, { buffer = bufnr, expr = true, nowait = true })

  self.mappings[bufnr][mapName] = config_lhs
end

function Signature:remove_mappings(bufnr, mode)
  for _, buf_local_mappings in pairs(self.mappings) do
    for _, value in pairs(buf_local_mappings) do
      vim.keymap.del(mode, value, { buffer = bufnr, silent = true })
    end
  end

  self.mappings = {}
end

function Signature:create_signature_popup()
  self.signature_content:add_content(self)

  -- Try and place the floating window above the cursor. If there is not enough room,
  -- fallback to the default behaviour of nvim_open_win
  if self.config.floating_window_above_cur_line then
    local _, height = vim.lsp.util._make_floating_popup_size(self.signature_content.content, self.config)

    local lines_above = vim.fn.winline() - 1
    if lines_above > height then
      self.config.offset_y = -height - 3 -- -3 brings the bottom of the popup above the current line
    end
  end

  -- This will replace the existing lsp signature popup if it existsk with a new one.
  -- so keep track of new buffer and win numbers
  local fbuf, fwin = vim.lsp.util.open_floating_preview(self.signature_content.content, "markdown", self.config)
  if self.signature_content.active_hl then
    vim.api.nvim_buf_add_highlight(fbuf, -1, "LspSignatureActiveParameter", 0, unpack(self.signature_content.active_hl))
  end
  local bufnr = vim.api.nvim_get_current_buf()

  self.bufnr = bufnr
  self.fwin = fwin
end

return Signature
