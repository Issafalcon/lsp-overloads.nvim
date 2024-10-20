---@type SignatureContent
local SignatureContent = {
  contents = {},
  active_hl = nil,
  label_line = 0,
}

--- Taken from https://github.com/neovim/neovim/blob/master/runtime/lua/vim/lsp/util.lua#L896
--- Convert a signature help to markdown lines with slight modification to display the Overloads count
---@param signature_help
---@param ft
---@param triggers
---@return
local function convert_signature_help_to_markdown_lines(signature_help, ft, triggers)
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

  if signature.documentation then
    -- if LSP returns plain string, we treat it as plaintext. This avoids
    -- special characters like underscore or similar from being interpreted
    -- as markdown font modifiers
    if type(signature.documentation) == 'string' then
      signature.documentation = { kind = 'plaintext', value = signature.documentation }
    end

    local comment_beginning = ft == 'lua' and '-- ' or '/**'
    if string.sub(signature.documentation.value, 1, 3) ~= comment_beginning then
      local documentation = ft == 'lua' and {} or { '/**' }
      for line in signature.documentation.value:gmatch('[^\n]+') do
        table.insert(documentation, (ft ~= 'lua' and ' * ' or '-- ') .. line)
      end
      if ft ~= 'lua' then
        table.insert(documentation, ' */')
      end

      signature.documentation.value = table.concat(documentation, '\n')
      signature.documentation.label_line = #documentation
    end
    vim.lsp.util.convert_input_to_markdown_lines(signature.documentation, contents)
  end

  local label = signature.label
  vim.list_extend(contents, vim.split(label, '\n', { plain = true, trimempty = true }))

  -- This is the modification to display the Overloads count
  if #signature_help.signatures > 1 then
    vim.list_extend(
      contents,
      { '(Overload ' .. active_signature + 1 .. ' of ' .. #signature_help.signatures .. ')', '' }
    )
  end

  if signature.parameters and #signature.parameters > 0 then
    local active_parameter = (signature.activeParameter or signature_help.activeParameter or 0)
    if active_parameter < 0 then
      active_parameter = 0
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
        if type(parameter.label) == 'table' then
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

  return contents, active_hl, (signature and signature.documentation) and signature.documentation.label_line or 0
end

local function trim_empty_lines(lines)
  local start = 1
  for i = 1, #lines do
    if lines[i] ~= nil and #lines[i] > 0 then
      start = i
      break
    end
  end
  local finish = 1
  for i = #lines, 1, -1 do
    if lines[i] ~= nil and #lines[i] > 0 then
      finish = i
      break
    end
  end
  return vim.list_extend({}, lines, start, finish)
end

--- Create a new SignatureContent object
---@return SignatureContent The signature content object
function SignatureContent:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

--- Adds the contents of the signature to the signature content object
---@param signature Signature The signature object to modify the contents for
function SignatureContent:add_content(signature)
  local client = vim.lsp.get_client_by_id(signature.ctx.client_id)
  local triggers = vim.tbl_get(client.server_capabilities, 'signatureHelpProvider', 'triggerCharacters')
  local ft = vim.bo[signature.ctx.bufnr].filetype

  self.contents, self.active_hl, self.label_line = convert_signature_help_to_markdown_lines(signature, ft, triggers)

  self.contents = trim_empty_lines(self.contents)
  if vim.tbl_isempty(self.contents) then
    if signature.config.silent ~= true then
      print('No signature help available')
    end
    return
  end
end

return SignatureContent
