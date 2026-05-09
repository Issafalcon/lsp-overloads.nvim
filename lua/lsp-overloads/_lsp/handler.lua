--- LSP textDocument/signatureHelp response handler for lsp-overloads.nvim.
--- Replaces the native Neovim handler to provide overload cycling support.

---@module "lsp-overloads.types"
---@module "lsp-overloads._core.configuration"
---@module "lsp-overloads._lsp.signature"
---@module "lsp-overloads._lsp.autocommands"
---@module "lsp-overloads._lsp.mappings"

local configuration = require("lsp-overloads._core.configuration")
local signature = require("lsp-overloads._lsp.signature")
local autocommands = require("lsp-overloads._lsp.autocommands")
local mappings = require("lsp-overloads._lsp.mappings")

local M = {}

--- The LSP signatureHelp response handler.
--- This is installed as vim.lsp.handlers["textDocument/signatureHelp"] when
--- override_native_handler = true (the default).
---
---@param err any LSP error or nil
---@param result table? Raw signatureHelp LSP result
---@param ctx table LSP context (method, client_id, bufnr)
---@param config table Options from vim.lsp.with()
function M.handler(err, result, ctx, config)
  if result == nil or not result.signatures or #result.signatures == 0 then
    if config and not config.silent and not configuration.current.ui.silent then
      vim.notify("[lsp-overloads] No signature help available", vim.log.levels.INFO)
    end
    return
  end

  config = config or {}
  config.focus_id = ctx.method

  local state = signature.new(result, err, ctx, config)

  signature.open_popup(state)

  if not state.fwin then
    return
  end

  autocommands.setup(state)

  mappings.setup(
    state,
    -- modify callback: cycle overload or parameter, then refresh popup
    function(s, opts)
      signature.cycle(s, opts)
    end,
    -- close callback
    function(s)
      signature.close_popup(s)
    end
  )
end

--- Check whether the text typed up to the cursor ends with a trigger character.
---
---@param line_to_cursor string Text from line start to cursor
---@param triggers string[]? Server's trigger characters
---@return boolean
local function check_trigger_char(line_to_cursor, triggers)
  if not triggers then
    return false
  end
  for _, trigger_char in ipairs(triggers) do
    local current_char = line_to_cursor:sub(-1)
    local prev_char = #line_to_cursor > 1 and line_to_cursor:sub(-2, -2) or ""
    if current_char == trigger_char or (current_char == " " and prev_char == trigger_char) then
      if trigger_char == "," then
        return M.check_inside_call(line_to_cursor)
      end
      return true
    end
  end
  return false
end

--- Check whether the cursor is inside a function call (open paren not yet closed).
--- Guards against showing signature help while typing tuple arguments outside a call.
---
---@param line_to_cursor string
---@return boolean
function M.check_inside_call(line_to_cursor)
  if not line_to_cursor:match("%(") then
    return false
  end
  local open_count = select(2, line_to_cursor:gsub("%(", ""))
  local close_count = select(2, line_to_cursor:gsub("%)", ""))
  return open_count > close_count
end

--- Request signature help for the current cursor position.
--- Called by the TextChangedI autocmd and the :LspOverloads signature command.
---
--- NOTE: We intentionally avoid vim.lsp.buf.signature_help() here.  In Neovim
--- 0.12 that function was rewritten to aggregate results inline (never calling
--- the registered handler) and adds a native <C-s>-cycling float.  We bypass
--- it entirely and drive the request through buf_request_all() so that our own
--- M.handler() always runs.
---
---@param bypass_trigger boolean? If true, skip trigger-character checking (manual invocation)
function M.open_signature(bypass_trigger)
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })

  -- Filter to clients that provide signature help
  clients = vim
    .iter(clients)
    :filter(function(c)
      return vim.tbl_get(c, "server_capabilities", "signatureHelpProvider") ~= nil
    end)
    :totable()

  if #clients == 0 then
    return
  end

  local triggered = bypass_trigger or false
  local line_to_cursor = ""

  if not triggered then
    local pos = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_get_current_line()
    line_to_cursor = line:sub(1, pos[2])

    for _, client in ipairs(clients) do
      local triggers = vim.tbl_get(client.server_capabilities, "signatureHelpProvider", "triggerCharacters")
      -- clangd / csharp workaround: some servers report wrong triggers
      if client.name == "csharp" then
        triggers = { "(", "," }
      end
      if check_trigger_char(line_to_cursor, triggers) then
        triggered = true
        break
      end
    end

    -- Also re-trigger when the cursor is already inside a call so parameter
    -- highlighting tracks each keystroke the user types.
    if not triggered then
      triggered = M.check_inside_call(line_to_cursor)
    end
  end

  if not triggered then
    return
  end

  local cfg = configuration.current
  -- Build the config that will be forwarded to our handler (and on to
  -- open_floating_preview).  focus_id groups the window so Neovim can reuse
  -- the same float rather than stacking multiple ones.
  local req_config = {
    border = cfg.ui.border,
    silent = cfg.ui.silent,
    height = cfg.ui.height,
    width = cfg.ui.width,
    wrap = cfg.ui.wrap,
    wrap_at = cfg.ui.wrap_at,
    max_width = cfg.ui.max_width,
    max_height = cfg.ui.max_height,
    focusable = cfg.ui.focusable,
    focus = cfg.ui.focus,
    offset_x = cfg.ui.offset_x,
    offset_y = cfg.ui.offset_y,
    close_events = cfg.ui.close_events,
    floating_window_above_cur_line = cfg.ui.floating_window_above_cur_line,
    zindex = cfg.ui.zindex,
    focus_id = "textDocument/signatureHelp",
  }

  -- Use make_position_params from the first capable client for compatibility
  -- across Neovim versions (0.11 buf_request_all expects a table, not a fn).
  local params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)

  vim.lsp.buf_request_all(bufnr, "textDocument/signatureHelp", params, function(results)
    for client_id, r in pairs(results) do
      if not r.err and r.result and r.result.signatures and #r.result.signatures > 0 then
        local ctx = {
          method = "textDocument/signatureHelp",
          client_id = client_id,
          bufnr = bufnr,
        }
        M.handler(r.err, r.result, ctx, req_config)
        -- Use the first successful result only
        return
      end
    end
  end)
end

return M
