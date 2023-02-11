---@module "lsp-overloads.settings"
local settings = require("lsp-overloads.settings")
local Signature = require("lsp-overloads.models.signature")
local autocommands = require("lsp-overloads.autocommands")

local M = {}

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
    if current_char == " " and prev_char == trigger_char then
      return true
    end
  end
  return false
end

--- Modified code from https://github.com/neovim/neovim/blob/1a20aed3fb35e00f96aa18abb69d35912c9e119d/runtime/lua/vim/lsp/handlers.lua#L382
M.signature_handler = function(err, result, ctx, config)
  if result == nil then
    return
  end

  -- When use `autocmd CompleteDone <silent><buffer> lua vim.lsp.buf.signature_help()` to call signatureHelp handler
  -- If the completion item doesn't have signatures It will make noise. Change to use `print` that can use `<silent>` to ignore
  if not (result and result.signatures and result.signatures[1]) then
    if config and config.silent ~= true then
      print("No signature help available")
    end
    return
  end

  config = config or {}
  config.focus_id = ctx.method

  local signature = Signature:new()
  signature:update_with_lsp_response(err, result, ctx, config)
  signature:create_signature_popup()

  autocommands.setup_signature_augroup(signature)
  M.add_signature_mappings(signature)
end

--- Opens the signature help popup for the current line
---@param clients table List of lsp_clients to use for signature help
---@param bypass_trigger boolean Whether or not to bypass the check for trigger characters
---   used for manaully triggering the function (e.g. via a keymap)
M.open_signature = function(clients, bypass_trigger)
  local triggered = bypass_trigger or false

  for _, client in pairs(clients) do
    local triggers = client.server_capabilities.signatureHelpProvider.triggerCharacters

    -- csharp has wrong trigger chars for some odd reason
    if client.name == "csharp" then
      triggers = { "(", "," }
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
      "textDocument/signatureHelp",
      params,
      vim.lsp.with(M.signature_handler, {
        border = settings.current.ui.border,
        silent = true,
        height = settings.current.ui.height,
        width = settings.current.ui.width,
        wrap = settings.current.ui.wrap,
        wrap_at = settings.current.ui.wrap_at,
        max_width = settings.current.ui.max_width,
        max_height = settings.current.ui.max_height,
        focusable = settings.current.ui.focusable,
        focus = settings.current.ui.focus,
        offset_x = settings.current.ui.offset_x,
        offset_y = settings.current.ui.offset_y,
        close_events = settings.current.ui.close_events,
        floating_window_above_cur_line = settings.current.ui.floating_window_above_cur_line,
      })
    )
  end
end

return M
