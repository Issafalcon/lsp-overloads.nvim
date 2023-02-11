-- Add current directory to 'runtimepath' to be able to use 'lua' files
vim.cmd([[let &rtp.=','.getcwd()]])

-- When running headless only (i.e. via Makefile command)
if #vim.api.nvim_list_uis() == 0 then
  -- Add dependenices to rtp (installed via the Makefile 'deps' command)
  local plenary_path = vim.fn.getcwd() .. "/deps/plenary"
  local mini_path = vim.fn.getcwd() .. "/deps/mini.doc.nvim"

  vim.cmd("set rtp+=" .. plenary_path)
  vim.cmd("set rtp+=" .. mini_path)

  -- Source the plugin dependency files
  vim.cmd("runtime plugin/plenary.vim")
  vim.cmd("runtime lua/mini/doc.lua")
end
