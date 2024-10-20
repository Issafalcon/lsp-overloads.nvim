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
    local original_map = vim.fn.maparg(config_lhs, self.mode, false, true)
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
        vim.api.nvim_buf_call(bufnr, function()
          vim.fn.mapset(self.mode, false, original_buf_map)
        end)
        self.original_buf_mappings[bufnr][lhs] = nil
      end
    end
  end

  self.mappings = {}
end

local api = vim.api
local npcall = vim.F.npcall
local validate = vim.validate

local function find_window_by_var(name, value)
  for _, win in ipairs(api.nvim_list_wins()) do
    if npcall(api.nvim_win_get_var, win, name) == value then
      return win
    end
  end
end

--- Closes the preview window
---
---@param winnr integer window id of preview window
---@param bufnrs table|nil optional list of ignored buffers
local function close_preview_window(winnr, bufnrs)
  vim.schedule(function()
    -- exit if we are in one of ignored buffers
    if bufnrs and vim.list_contains(bufnrs, api.nvim_get_current_buf()) then
      return
    end

    local augroup = "preview_window_" .. winnr
    pcall(api.nvim_del_augroup_by_name, augroup)
    pcall(api.nvim_win_close, winnr, true)
  end)
end

local function close_preview_autocmd(events, winnr, bufnrs)
  local augroup = api.nvim_create_augroup("preview_window_" .. winnr, {
    clear = true,
  })

  -- close the preview window when entered a buffer that is not
  -- the floating window buffer or the buffer that spawned it
  api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    callback = function()
      close_preview_window(winnr, bufnrs)
    end,
  })

  if #events > 0 then
    api.nvim_create_autocmd(events, {
      group = augroup,
      buffer = bufnrs[2],
      callback = function()
        close_preview_window(winnr)
      end,
    })
  end
end

local function open_floating_preview(contents, syntax, opts)
  validate({
    contents = { contents, "t" },
    syntax = { syntax, "s", true },
    opts = { opts, "t", true },
  })
  opts = opts or {}
  opts.wrap = opts.wrap ~= false -- wrapping by default
  opts.focus = opts.focus ~= false
  opts.close_events = opts.close_events or { "CursorMoved", "CursorMovedI", "InsertCharPre" }

  local bufnr = api.nvim_get_current_buf()

  -- check if this popup is focusable and we need to focus
  if opts.focus_id and opts.focusable ~= false and opts.focus then
    -- Go back to previous window if we are in a focusable one
    local current_winnr = api.nvim_get_current_win()
    if npcall(api.nvim_win_get_var, current_winnr, opts.focus_id) then
      api.nvim_command("wincmd p")
      return bufnr, current_winnr
    end
    do
      local win = find_window_by_var(opts.focus_id, bufnr)
      if win and api.nvim_win_is_valid(win) and vim.fn.pumvisible() == 0 then
        -- focus and return the existing buf, win
        api.nvim_set_current_win(win)
        api.nvim_command("stopinsert")
        return api.nvim_win_get_buf(win), win
      end
    end
  end

  -- check if another floating preview already exists for this buffer
  -- and close it if needed
  local existing_winnr = npcall(api.nvim_buf_get_var, bufnr, "lsp_floating_preview")
  local floating_winnr
  local floating_bufnr
  local modifying = false
  if existing_winnr and api.nvim_win_is_valid(existing_winnr) then
    floating_winnr = existing_winnr
    floating_bufnr = vim.api.nvim_win_get_buf(floating_winnr)
    modifying = true
  end

  if not modifying then
    -- Create the buffer
    floating_bufnr = api.nvim_create_buf(false, true)
  end

  -- Set up the contents, using treesitter for markdown
  local do_stylize = syntax == "markdown" and vim.g.syntax_on ~= nil
  if do_stylize then
    local width = vim.lsp.util._make_floating_popup_size(contents, opts)
    contents = vim.lsp.util._normalize_markdown(contents, { width = width })
    vim.bo[floating_bufnr].filetype = "markdown"
    vim.treesitter.start(floating_bufnr)
    api.nvim_buf_set_lines(floating_bufnr, 0, -1, false, contents)
  else
    -- Clean up input: trim empty lines
    contents = vim.split(table.concat(contents, "\n"), "\n", { trimempty = true })

    if syntax then
      vim.bo[floating_bufnr].syntax = syntax
    end
    api.nvim_buf_set_lines(floating_bufnr, 0, -1, true, contents)
  end

  -- Compute size of float needed to show (wrapped) lines
  if opts.wrap then
    opts.wrap_at = opts.wrap_at or api.nvim_win_get_width(0)
  else
    opts.wrap_at = nil
  end
  local width, height = vim.lsp.util._make_floating_popup_size(contents, opts)

  local float_option = vim.lsp.util.make_floating_popup_options(width, height, opts)
  if not modifying then
    floating_winnr = api.nvim_open_win(floating_bufnr, false, float_option)
  else
    vim.api.nvim_win_set_config(floating_winnr, float_option)
  end

  if do_stylize then
    vim.wo[floating_winnr].conceallevel = 2
  end
  -- disable folding
  vim.wo[floating_winnr].foldenable = false
  -- soft wrapping
  vim.wo[floating_winnr].wrap = opts.wrap

  vim.bo[floating_bufnr].bufhidden = "wipe"

  api.nvim_buf_set_keymap(
    floating_bufnr,
    "n",
    "q",
    "<cmd>bdelete<cr>",
    { silent = true, noremap = true, nowait = true }
  )
  close_preview_autocmd(opts.close_events, floating_winnr, { floating_bufnr, bufnr })

  -- save focus_id
  if opts.focus_id then
    api.nvim_win_set_var(floating_winnr, opts.focus_id, bufnr)
  end
  api.nvim_buf_set_var(bufnr, "lsp_floating_preview", floating_winnr)

  return floating_bufnr, floating_winnr
end

function Signature:create_signature_popup()
  self.signature_content:add_content(self)

  local _, height = vim.lsp.util._make_floating_popup_size(self.signature_content.contents, self.config)
  self.config.offset_y = -height - 3 -- -3 brings the bottom of the popup above the current line

  -- This will replace the existing lsp signature popup if it existsk with a new one.
  -- so keep track of new buffer and win numbers
  local fbuf, fwin = open_floating_preview(self.signature_content.contents, "markdown", self.config)
  if self.signature_content.active_hl then
    vim.api.nvim_buf_add_highlight(
      fbuf,
      -1,
      "LspSignatureActiveParameter",
      self.signature_content.label_line,
      unpack(self.signature_content.active_hl)
    )
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
