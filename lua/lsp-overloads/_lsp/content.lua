--- Converts LSP signatureHelp responses into popup-ready markdown lines.
--- Extracted from the original models/signature-content.lua and modernised.

---@module "lsp-overloads.types"

local M = {}

--- Convert a signatureHelp LSP result to markdown lines for display.
--- Modelled on vim.lsp.util.convert_signature_help_to_markdown_lines but with
--- overload count annotation and preserved active-parameter highlighting.
---
---@param signature_help table The raw signatureHelp result from the LSP server
---@param ft string? The filetype of the source buffer (used for syntax fencing)
---@param triggers string[]? Trigger characters from server capabilities
---@return string[]? contents  The markdown lines ready for open_floating_preview
---@return integer[]? active_hl [start_col, end_col] of active-param highlight (0-based)
function M.to_markdown_lines(signature_help, ft, triggers)
  if not signature_help or not signature_help.signatures then
    return nil, nil
  end

  local contents = {}
  local active_hl

  local active_signature = signature_help.activeSignature or 0
  if active_signature < 0 or active_signature >= #signature_help.signatures then
    active_signature = 0
  end

  local signature = signature_help.signatures[active_signature + 1]
  if not signature then
    return nil, nil
  end

  -- Signature label (optionally wrapped in a code fence for syntax highlight)
  local label = signature.label
  if ft then
    label = ("```%s\n%s\n```"):format(ft, label)
  end
  vim.list_extend(contents, vim.split(label, "\n", { plain = true, trimempty = true }))

  -- Signature documentation
  if signature.documentation then
    if type(signature.documentation) == "string" then
      signature.documentation = { kind = "plaintext", value = signature.documentation }
    end
    vim.lsp.util.convert_input_to_markdown_lines(signature.documentation, contents)
  end

  -- Overload count indicator with configured cycle keybinds
  if #signature_help.signatures > 1 then
    local km_hint = ""
    local ok, cfg = pcall(require, "lsp-overloads._core.configuration")
    if ok then
      local km = cfg.current.keymaps
      if km.previous_signature and km.next_signature then
        km_hint = string.format(" | %s/%s to cycle", km.previous_signature, km.next_signature)
      end
    end
    vim.list_extend(contents, {
      ("(Overload %d of %d%s)"):format(active_signature + 1, #signature_help.signatures, km_hint),
      "",
    })
  end

  -- Active parameter highlight
  if signature.parameters and #signature.parameters > 0 then
    local active_parameter = signature.activeParameter or signature_help.activeParameter or 0
    if active_parameter < 0 then
      active_parameter = 0
    end
    if active_parameter >= #signature.parameters then
      active_parameter = #signature.parameters - 1
    end

    local parameter = signature.parameters[active_parameter + 1]
    if parameter then
      if parameter.label then
        if type(parameter.label) == "table" then
          -- label is already [start, end] offsets
          active_hl = parameter.label
        else
          -- label is a string: find its position within the signature label
          local offset = 1
          -- try to start search from the first trigger character occurrence
          for _, t in ipairs(triggers or {}) do
            local trigger_offset = signature.label:find(t, 1, true)
            if trigger_offset and (offset == 1 or trigger_offset < offset) then
              offset = trigger_offset
            end
          end
          for p, param in ipairs(signature.parameters) do
            offset = signature.label:find(param.label, offset, true)
            if not offset then
              break
            end
            if p == active_parameter + 1 then
              active_hl = { offset - 1, offset + #parameter.label - 1 }
              break
            end
            offset = offset + #param.label + 1
          end
        end
      end
      if parameter.documentation then
        vim.lsp.util.convert_input_to_markdown_lines(parameter.documentation, contents)
      end
    end
  end

  return contents, active_hl
end

--- Render a SignatureState into popup content.
---
---@param state lsp-overloads.SignatureState
---@return lsp-overloads.SignatureContent
function M.render(state)
  local client = vim.lsp.get_client_by_id(state.ctx.client_id)
  local triggers = client and vim.tbl_get(client.server_capabilities, "signatureHelpProvider", "triggerCharacters")
    or {}
  local ft = state.ctx.bufnr and vim.bo[state.ctx.bufnr].filetype or nil

  local contents, active_hl = M.to_markdown_lines(state, ft, triggers)

  if contents then
    contents = vim.lsp.util.trim_empty_lines(contents)
  end

  if not contents or vim.tbl_isempty(contents) then
    return { contents = nil, active_hl = nil, label_line = 0 }
  end

  local label_line = vim.startswith(contents[1], "```") and 1 or 0

  ---@type lsp-overloads.SignatureContent
  return {
    contents = contents,
    active_hl = active_hl,
    label_line = label_line,
  }
end

return M
