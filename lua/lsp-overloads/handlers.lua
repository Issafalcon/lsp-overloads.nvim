---@module "lsp-overloads.settings"
local settings = require("lsp-overloads.settings")
local Signature = require("lsp-overloads.models.signature")
local autocommands = require("lsp-overloads.autocommands")
local mappings = require("lsp-overloads.mappings")

local M = {}

if settings.current.ui.highlight then
  vim.api.nvim_set_hl(0, "LspSignatureActiveParameter", settings.current.ui.highlight)
end

--- Helper function to prevent multiple signature popups from opening whilst entering a tuple argument.
--- Makes the assumption that the language calls functions using parentheses, and tuples / argument lists are also enclosed in parentheses.
---@param line_to_cursor string The text contained in the line up to the current cursor position
---@return boolean Whether or not the cursor is inside a tuple
local function check_tuple(line_to_cursor)
  -- Quick return if there are no open parens (i.e. Not in a supported function call)
  if not line_to_cursor:match("%(") then
    return true
  end

  local open_parens = 0
  local closed_parens = 0
  for _ in line_to_cursor:gmatch("%(") do
    open_parens = open_parens + 1
  end
  for _ in line_to_cursor:gmatch("%)") do
    closed_parens = closed_parens + 1
  end

  return open_parens == closed_parens + 1 and true or false
end

---@param line_to_cursor string Text of the line up to the current cursor
---@param triggers table List of the trigger chars for firing a textDocument/signatureHelp request
local check_trigger_char = function(line_to_cursor, triggers)
  if not triggers then
    return false
  end

  for _, trigger_char in ipairs(triggers) do
    -- Check if cursor is inside a tuple
    local current_char = line_to_cursor:sub(#line_to_cursor, #line_to_cursor)
    local prev_char = line_to_cursor:sub(#line_to_cursor - 1, #line_to_cursor - 1)
    if current_char == trigger_char then
      if trigger_char == "," then
        return check_tuple(line_to_cursor)
      end
      return true
    end
    if current_char == " " and prev_char == trigger_char then
      if trigger_char == "," then
        return check_tuple(line_to_cursor)
      end
      return true
    end
  end
  return false
end

M.signature_handler = function(err, result, ctx, config)
  if result == nil then
    return
  end

  -- When use `autocmd CompleteDone <silent><buffer> lua vim.lsp.buf.signature_help()` to call signatureHelp handler
  -- If the completion item doesn't have signatures It will make noise. Change to use `print` that can use `<silent>` to ignore
  if not (result and result.signatures and result.signatures[1]) then
    if config and config.silent ~= true then
      vim.notify("No signature help available")
    end
    return
  end

  config = config or {}
  config.focus_id = ctx.method

  local signature = Signature:new(result)
  signature:update_with_lsp_response(err, ctx, config)
  signature:create_signature_popup()

  autocommands.setup_signature_augroup(signature)
  mappings.add_signature_mappings(signature)
end

--- Opens the signature help popup for the current line
---@param clients table List of lsp_clients to use for signature help
---@param[opt=false] bypass_trigger boolean Whether or not to bypass the check for trigger characters
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
    local win = vim.api.nvim_get_current_win()
    local enc = (vim.lsp.get_clients({ bufnr = 0 })[1]).offset_encoding
    local params = vim.lsp.util.make_position_params(win, enc)
    vim.lsp.buf_request(
      0,
      "textDocument/signatureHelp",
      params,
      vim.lsp.with(M.signature_handler, {
        border = settings.current.ui.border,
        silent = settings.current.ui.silent,
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
