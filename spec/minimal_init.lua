--- Bootstrap file for busted test suite (run via PlenaryBustedDirectory).
--- Run before any spec files to set up the Neovim runtime environment.

-- Add the plugin itself to the runtimepath
vim.opt.rtp:prepend(vim.fn.getcwd())

-- Add plenary from the system-installed location
local plenary_path = vim.fn.getcwd() .. "/deps/plenary"
if vim.fn.isdirectory(plenary_path) == 1 then
  vim.opt.rtp:prepend(plenary_path)
  vim.cmd("runtime plugin/plenary.vim")
end

-- Run the plugin entry point so commands are registered
vim.cmd("runtime plugin/lsp_overloads.lua")
