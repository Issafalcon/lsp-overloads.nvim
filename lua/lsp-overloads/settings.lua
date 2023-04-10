local M = {}

---@type LspOverloadsSettings
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
    close_signature = "<A-s>",
  },
  display_automatically = true,
  silent = false,
}

M._DEFAULT_SETTINGS = DEFAULT_SETTINGS
M.current = M._DEFAULT_SETTINGS

---@param opts LspOverloadsSettings
function M.set(opts)
  M.current = vim.tbl_deep_extend("force", M.current, opts)
end

return M
