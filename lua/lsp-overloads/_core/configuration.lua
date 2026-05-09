--- Configuration management for lsp-overloads.nvim.
--- Provides default settings, user config merging, and a one-time init guard.

---@module "lsp-overloads.types"

local M = {}

-- Guard flag: prevents re-initialisation on subsequent require() calls
vim.g.loaded_lsp_overloads = vim.g.loaded_lsp_overloads or false

---@type lsp-overloads.Config
local _DEFAULTS = {
  ui = {
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
    silent = true,
    floating_window_above_cur_line = false,
    zindex = 50,
  },
  keymaps = {
    next_signature = "<C-j>",
    previous_signature = "<C-k>",
    next_parameter = "<C-l>",
    previous_parameter = "<C-h>",
    close_signature = "<A-s>",
    scroll_down = "<C-d>",
    scroll_up = "<C-u>",
  },
  display_automatically = true,
  override_native_handler = true,
  silent = false,
  log_level = "warn",
}

---@type lsp-overloads.Config
M.current = vim.deepcopy(_DEFAULTS)

--- Returns a copy of the default configuration.
---@return lsp-overloads.Config
function M.defaults()
  return vim.deepcopy(_DEFAULTS)
end

--- Merge user-provided options into the current configuration.
--- Safe to call multiple times; later calls extend rather than replace.
---@param opts lsp-overloads.Config?
function M.set(opts)
  if opts then
    M.current = vim.tbl_deep_extend("force", M.current, opts)
  end
end

--- One-time initialisation from vim.g.lsp_overloads_config (for lazy.nvim config table).
--- Only runs once per Neovim session.
function M.initialize_if_needed()
  if vim.g.loaded_lsp_overloads then
    return
  end
  local g_config = vim.g.lsp_overloads_config
  if g_config then
    M.set(g_config)
  end
  vim.g.loaded_lsp_overloads = true
end

--- Reset configuration to defaults. Used in tests.
function M.reset()
  M.current = vim.deepcopy(_DEFAULTS)
  vim.g.loaded_lsp_overloads = false
end

return M
