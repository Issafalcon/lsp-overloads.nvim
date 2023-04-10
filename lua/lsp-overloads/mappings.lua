local settings = require("lsp-overloads.settings")
local autocommands = require("lsp-overloads.autocommands")

local M = {}

local function modify_signature(opts)
  -- Editing buffers is not allowed from <expr> mappings. The popup mappings are
  -- all <expr> mappings so they can be used consistently across modes, so instead
  -- of running the functions directly, they are run in an immediately executed
  -- timer callback.
  vim.fn.timer_start(0, function()
    -- See https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#signatureHelp

    -- Set the root level active signature in case the LSP response doesn't provide one (it's an optional property according to the spec, but
    -- we need it for the calculations)
    opts.signature.activeSignature = opts.signature.activeSignature or 0
    opts.signature:modify_active_signature(opts.sig_modifier)
    opts.signature:modify_active_param(opts.param_modifier)

    -- TODO: Make the variable name a constant somewhere
    -- Set this variable to indicate that the signature popup is swapping overloads, so don't delete the signature object.
    vim.api.nvim_buf_set_var(opts.signature.bufnr, "is_swapping_overload", opts.signature.fwin)

    opts.signature:create_signature_popup()

    autocommands.setup_signature_augroup(opts.signature)
    M.add_signature_mappings(opts.signature)
  end)
end

local function close_signature(opts)
  opts.signature:close_signature_popup()
end

function M.add_signature_mappings(signature)
  signature:add_mapping(
    "sig_next",
    settings.current.keymaps.next_signature,
    modify_signature,
    { signature = signature, sig_modifier = 1, param_modifier = 0 }
  )
  signature:add_mapping(
    "sig_prev",
    settings.current.keymaps.previous_signature,
    modify_signature,
    { signature = signature, sig_modifier = -1, param_modifier = 0 }
  )
  signature:add_mapping(
    "param_next",
    settings.current.keymaps.next_parameter,
    modify_signature,
    { signature = signature, sig_modifier = 0, param_modifier = 1 }
  )
  signature:add_mapping(
    "param_prev",
    settings.current.keymaps.previous_parameter,
    modify_signature,
    { signature = signature, sig_modifier = 0, param_modifier = -1 }
  )
  signature:add_mapping("close", settings.current.keymaps.close_signature, close_signature, { signature = signature })
end

return M
