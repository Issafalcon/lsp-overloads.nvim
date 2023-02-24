local function lsp_overloads_signature()
  require("lsp-overloads").user_request_overloads_signature()
end

vim.api.nvim_create_user_command("LspOverloadsSignature", lsp_overloads_signature, {
  desc = "Triggers the lspoverloads signature request",
  nargs = 0,
})


local function lsp_overloads_signature_toggle()
  require("lsp-overloads").toggle()
end
vim.api.nvim_create_user_command("LspOverloadsSignatureToggle", lsp_overloads_signature_toggle, {
  desc = "Toggles the lspoverloads signature display",
  nargs = 0,
})
