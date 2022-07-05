---@module "lsp-overloads.ui.signature_popup"
local sig_popup = require("lsp-overloads.ui.signature_popup")
---@module "lsp-overloads.settings"
local settings = require("lsp-overloads.settings")

local M = {}
local last_signature = {}

local modify_sig = function(opts)
  -- Editing buffers is not allowed from <expr> mappings. The popup mappings are
  -- all <expr> mappings so they can be used consistently across modes, so instead
  -- of running the functions directly, they are run in an immediately executed
  -- timer callback.
  vim.fn.timer_start(0, function()
    local next_possible_sig_idx = last_signature.activeSignature + (opts.sig_modifier or 0)
    local next_possible_param_idx = last_signature.activeParameter + (opts.param_modifier or 0)

    if next_possible_sig_idx >= 0 and #last_signature.signatures - 1 >= next_possible_sig_idx then
      last_signature.activeSignature = next_possible_sig_idx
    end

    if next_possible_param_idx >= 0
        and
        last_signature.signatures[last_signature.activeSignature + 1] ~= nil
        and
        (#last_signature.signatures[last_signature.activeSignature + 1].parameters - 1) >= next_possible_param_idx
    then
      last_signature.activeParameter = next_possible_param_idx
    end

    M.signature_handler(last_signature.err, last_signature, last_signature.ctx,
      last_signature.config)
  end)
end

---@param line_to_cursor string Text of the line up to the current cursor
---@param triggers list List of the trigger chars for firing a textDocument/signatureHelp request
local check_trigger_char = function(line_to_cursor, triggers)
  if not triggers then
    return false
  end

  for _, trigger_char in ipairs(triggers) do
    local current_char = line_to_cursor:sub(#line_to_cursor, #line_to_cursor)
    local prev_char = line_to_cursor:sub(#line_to_cursor - 1, #line_to_cursor - 1)
    if current_char == trigger_char then
      return true
    end
    if current_char == ' ' and prev_char == trigger_char then
      return true
    end
  end
  return false
end

local function add_signature_mappings(bufnr)
  sig_popup.add_mapping(bufnr, last_signature.mode, 'sig_next', settings.current.keymaps.next_signature, modify_sig,
    { sig_modifier = 1, param_modifier = 0 })
  sig_popup.add_mapping(bufnr, last_signature.mode, 'sig_prev', settings.current.keymaps.previous_signature, modify_sig,
    { sig_modifier = -1, param_modifier = 0 })
  sig_popup.add_mapping(bufnr, last_signature.mode, 'param_next', settings.current.keymaps.next_parameter, modify_sig,
    { sig_modifier = 0, param_modifier = 1 })
  sig_popup.add_mapping(bufnr, last_signature.mode, 'param_prev', settings.current.keymaps.previous_parameter, modify_sig
    ,
    { sig_modifier = 0, param_modifier = -1 })
end

--- Modified code from https://github.com/neovim/neovim/blob/1a20aed3fb35e00f96aa18abb69d35912c9e119d/runtime/lua/vim/lsp/handlers.lua#L382
M.signature_handler = function(err, result, ctx, config)
  if result == nil then
    return
  end

  config = config or {}
  config.focus_id = ctx.method

  -- Clear the signature state and start from scratch based on the current
  -- line_to_cursor value
  last_signature = {}

  -- Store the new result in state so we can move between overloads and params
  last_signature = result
  last_signature.err = err
  last_signature.mode = vim.api.nvim_get_mode()["mode"]
  last_signature.ctx = ctx
  last_signature.config = config

  -- When use `autocmd CompleteDone <silent><buffer> lua vim.lsp.buf.signature_help()` to call signatureHelp handler
  -- If the completion item doesn't have signatures It will make noise. Change to use `print` that can use `<silent>` to ignore
  if not (result and result.signatures and result.signatures[1]) then
    ---@param err any
    if config.silent ~= true then
      print('No signature help available')
    end
    return
  end
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  local triggers = vim.tbl_get(client.server_capabilities, 'signatureHelpProvider', 'triggerCharacters')
  local ft = vim.api.nvim_buf_get_option(ctx.bufnr, 'filetype')

  local lines, hl = sig_popup.convert_signature_help_to_markdown_lines(result, ft, triggers)
  lines = vim.lsp.util.trim_empty_lines(lines)
  if vim.tbl_isempty(lines) then
    if config.silent ~= true then
      print('No signature help available')
    end
    return
  end
  local fbuf, fwin = vim.lsp.util.open_floating_preview(lines, 'markdown', config)
  if hl then
    vim.api.nvim_buf_add_highlight(fbuf, -1, 'LspSignatureActiveParameter', 0, unpack(hl))
  end
  local bufnr = vim.api.nvim_get_current_buf()

  local augroup = vim.api.nvim_create_augroup('LspSignature_popup_' .. fwin, { clear = false })
  vim.api.nvim_create_autocmd('WinClosed', {
    group = augroup,
    pattern = tostring(fwin),
    callback = function()
      local signature_popup = require("lsp-overloads.ui.signature_popup")
      signature_popup.remove_mappings(bufnr, last_signature.mode)
      vim.api.nvim_del_augroup_by_id(augroup)
    end
  })

  add_signature_mappings(bufnr)

  return fbuf, fwin
end

M.open_signature = function(clients)
  local triggered = false

  for _, client in pairs(clients) do
    local triggers = client.server_capabilities.signatureHelpProvider.triggerCharacters

    -- csharp has wrong trigger chars for some odd reason
    if client.name == 'csharp' then
      triggers = { '(', ',' }
    end

    local pos = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_get_current_line()
    local line_to_cursor = line:sub(1, pos[2])

    if not triggered then
      triggered = check_trigger_char(line_to_cursor, triggers)
    end
  end

  if triggered then
    local params = vim.lsp.util.make_position_params()
    vim.lsp.buf_request(
      0,
      'textDocument/signatureHelp',
      params,
      vim.lsp.with(M.signature_handler, {
        border = settings.current.ui.border,
        silent = true,
        focusable = false,
      }))
  end
end

return M
