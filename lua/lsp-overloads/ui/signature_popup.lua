local M = {}

---@alias SignatureMaps table<string, string>

---@alias PopupMappings table<string, SignatureMaps>

---@type PopupMappings
local sig_popup_mappings = {}

---@param bufnr number The buffer number of the active buffer
---@param mode '"i"'|'"n"'|'"v"'|'"x"' The vim mode to apply the mapping to
---@param mapName string The unique name of the mapping
---@param default_lhs string The key presses required to trigger the mapping
---@param rhs fun(opts?: table): nil The function to execute when mapping is triggers
---@param opts? table The options to pass to the rhs function
M.add_mapping = function(bufnr, mode, mapName, default_lhs, rhs, opts)
  if sig_popup_mappings[bufnr] == nil then
    sig_popup_mappings[bufnr] = {}
  end

  local config_lhs = sig_popup_mappings[bufnr][mapName] or default_lhs
  if config_lhs == nil then
    return
  end

  vim.keymap.set(mode, config_lhs, function()
    rhs(opts)
  end, { buffer = bufnr, expr = true, nowait = true })

  sig_popup_mappings[bufnr][mapName] = config_lhs
end

---@param bufnr number The buffer number of the active buffer
---@param mode '"i"'|'"n"'|'"v"'|'"x"' The mode to which the original mapping was applied to
M.remove_mappings = function(bufnr, mode)
  for _, buf_local_mappings in pairs(sig_popup_mappings) do
    for _, value in pairs(buf_local_mappings) do
      vim.keymap.del(mode, value, { buffer = bufnr, silent = true })
    end
  end

  sig_popup_mappings = {}
end

--- Converts `textDocument/SignatureHelp` response to markdown lines.
---
---@param signature_help any Response of `textDocument/SignatureHelp`
---@param ft? string optional filetype that will be use as the `lang` for the label markdown code block
---@param triggers? table<string> optional list of trigger characters from the lsp server. used to better determine parameter offsets
---@returns list of lines of converted markdown.
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_signatureHelp
M.convert_signature_help_to_markdown_lines = function(signature_help, ft, triggers)
  if not signature_help.signatures then
    return
  end
  --The active signature. If omitted or the value lies outside the range of
  --`signatures` the value defaults to zero or is ignored if `signatures.length
  --=== 0`. Whenever possible implementors should make an active decision about
  --the active signature and shouldn't rely on a default value.
  local contents = {}
  local active_hl
  local active_signature = signature_help.activeSignature or 0
  -- If the activeSignature is not inside the valid range, then clip it.
  -- In 3.15 of the protocol, activeSignature was allowed to be negative
  if active_signature >= #signature_help.signatures or active_signature < 0 then
    active_signature = 0
  end
  local signature = signature_help.signatures[active_signature + 1]
  if not signature then
    return
  end
  local label = signature.label
  if ft then
    -- wrap inside a code block so stylize_markdown can render it properly
    label = ("```%s\n%s\n```"):format(ft, label)
  end
  vim.list_extend(contents, vim.split(label, '\n', true))
  if signature.documentation then
    vim.lsp.util.convert_input_to_markdown_lines(signature.documentation, contents)
  end

  if #signature_help.signatures > 1 then
    vim.list_extend(contents,
      { "(Overload " .. active_signature + 1 .. " of " .. #signature_help.signatures .. ")", "" })
  end

  if signature.parameters and #signature.parameters > 0 then
    local active_parameter = (signature.activeParameter or signature_help.activeParameter or 0)
    if active_parameter < 0
    then active_parameter = 0
    end

    -- If the activeParameter is > #parameters, then set it to the last
    -- NOTE: this is not fully according to the spec, but a client-side interpretation
    if active_parameter >= #signature.parameters then
      active_parameter = #signature.parameters - 1
    end

    local parameter = signature.parameters[active_parameter + 1]
    if parameter then
      --[=[
      --Represents a parameter of a callable-signature. A parameter can
      --have a label and a doc-comment.
      interface ParameterInformation {
        --The label of this parameter information.
        --
        --Either a string or an inclusive start and exclusive end offsets within its containing
        --signature label. (see SignatureInformation.label). The offsets are based on a UTF-16
        --string representation as `Position` and `Range` does.
        --
        --*Note*: a label of type string should be a substring of its containing signature label.
        --Its intended use case is to highlight the parameter label part in the `SignatureInformation.label`.
        label: string | [number, number];
        --The human-readable doc-comment of this parameter. Will be shown
        --in the UI but can be omitted.
        documentation?: string | MarkupContent;
      }
      --]=]
      if parameter.label then
        if type(parameter.label) == "table" then
          active_hl = parameter.label
        else
          local offset = 1
          -- try to set the initial offset to the first found trigger character
          for _, t in ipairs(triggers or {}) do
            local trigger_offset = signature.label:find(t, 1, true)
            if trigger_offset and (offset == 1 or trigger_offset < offset) then
              offset = trigger_offset
            end
          end
          for p, param in pairs(signature.parameters) do
            offset = signature.label:find(param.label, offset, true)
            if not offset then break end
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

return M
