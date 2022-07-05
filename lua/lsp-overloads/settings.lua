local M = {}

---@class LspOverloadsKeymaps
---@field next_signature string
---@field previous_signature string
---@field next_parameter string
---@field previous_parameter string

---@class LspOverloadsUiOpts
---@field border '"none"'|'"single"'|'"double"'

---@class LspOverloadsSettings
---@field keymaps LspOverloadsKeymaps
---@field ui LspOverloadsUiOpts
local DEFAULT_SETTINGS = {
  ui = {
    -- The border to use for the signature popup window. Accepts same border values as |nvim_open_win()|.
    border = "single"
  },
  keymaps = {
    next_signature = "<C-j>",
    previous_signature = "<C-k>",
    next_parameter = "<C-l>",
    previous_parameter = "<C-h>",
  },
}

M._DEFAULT_SETTINGS = DEFAULT_SETTINGS
M.current = M._DEFAULT_SETTINGS

---@param opts LspOverloadsSettings
function M.set(opts)
  M.current = vim.tbl_deep_extend("force", M.current, opts)
  put(M.current)
end

return M
