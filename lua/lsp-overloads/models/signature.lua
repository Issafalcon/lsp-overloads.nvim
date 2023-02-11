local Signature = {
  signatures = {},
  activeSignature = nil,
  activeParameter = nil,
  err = {},
  ctx = {},
  config = {},
  mappings = {},
}

-- Make OOP signature
function Signature:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  return o
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

return Signature
