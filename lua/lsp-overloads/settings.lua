local M = {}

---@class LspOverloadsKeymaps
---@field next_signature string
---@field previous_signature string
---@field next_parameter string
---@field previous_parameter string

---@class LspOverloadsUiOpts
---@field border '"none"'|'"single"'|'"double"'
---@field height number | nil Height of the signature window
---@field width number | nil Width of the signature window
---@field wrap boolean Wrap long lines
---@field wrap_at string | nil Character to wrap at for computing height when wrap enabled
---@field max_width number | nil maximal width of floating window
---@field max_height number | nil maximal height of floating window
---@field close_events table list of events that closes the floating window
---@field focusable boolean Make float focusable
---@field focus boolean If `true`, and if {focusable}
---             is also `true`, focus an existing floating window with the same
---             {focus_id}
---@field offset_x number Horizontal offset of the floating window relative to the cursor position
---@field offset_y number Vertical offset of the floating window relative to the cursor position
---@field floating_window_above_cur_line boolean If `true`, the floating window will be above the current line

---@class LspOverloadsSettings
---@field keymaps LspOverloadsKeymaps
---@field ui LspOverloadsUiOpts
local DEFAULT_SETTINGS = {
  ui = {
    -- The border to use for the signature popup window. Accepts same border values as |nvim_open_win()|.
    border = "single",
    height = nil,
    width = nil,
    wrap = true,
    wrap_at = nil,
    max_width = nil,
    max_height = nil,
    close_events = { "CursorMoved", "BufHidden", "InsertLeave" },
    focusable = true,
    focus = false,
    offset_x = 0,
    offset_y = 0,
    floating_window_above_cur_line = false,
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
end

return M
