local function lsp_overloads_signature()
  require("lsp-overloads").show()
end
vim.api.nvim_create_user_command("LspOverloadsSignature", lsp_overloads_signature, {
  desc = "Shows the lspoverloads signature display",
  nargs = 0,
})


local function lsp_overloads_signature_toggle_auto()
  require("lsp-overloads").toggle_automatic_display()
end
vim.api.nvim_create_user_command("LspOverloadsSignatureAutoToggle", lsp_overloads_signature_toggle_auto, {
  desc = "Toggles the lspoverloads signature automatic display on typing",
  nargs = 0,
})


local function lsp_overloads_signature_toggle_display()
  require("lsp-overloads").toggle_display()
end
vim.api.nvim_create_user_command("LspOverloadsSignatureDisplayToggle", lsp_overloads_signature_toggle_display, {
  desc = "Toggles the lspoverloads signature display",
  nargs = 0,
})

