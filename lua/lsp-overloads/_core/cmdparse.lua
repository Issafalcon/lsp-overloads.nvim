--- Simplified subcommand dispatcher for lsp-overloads.nvim.
--- Provides subcommand dispatch and tab-completion without external dependencies.
--- Mirrors the best-practices pattern from lumen-oss/nvim-best-practices.

---@class lsp-overloads.Subcommand
---@field impl fun(args: string[], opts: table) The subcommand implementation
---@field complete? fun(lead: string): string[] Optional tab-completion callback

local M = {}

--- Register a user command with subcommand dispatch and tab-completion.
---
---@param name string The command name (e.g. "LspOverloads")
---@param subcommands table<string, lsp-overloads.Subcommand> Map of subcommand name → handler
---@param opts? table Extra options passed to nvim_create_user_command
function M.create(name, subcommands, opts)
  opts = opts or {}

  ---@param cmd_opts table
  local function dispatch(cmd_opts)
    local fargs = cmd_opts.fargs
    local subcommand_key = fargs[1]
    local args = #fargs > 1 and vim.list_slice(fargs, 2, #fargs) or {}
    local subcommand = subcommands[subcommand_key]
    if not subcommand then
      error(string.format(
        "Unknown subcommand %q for %s. Available: %s",
        subcommand_key,
        name,
        table.concat(vim.tbl_keys(subcommands), ", ")
      ))
    end
    subcommand.impl(args, cmd_opts)
  end

  ---@param arg_lead string
  ---@param cmdline string
  local function complete(arg_lead, cmdline, _)
    -- If a subcommand has already been typed, delegate to its completer
    local subcmd_key, subcmd_arg_lead = cmdline:match("^['<,'>]*" .. name .. "[!]*%s+(%S+)%s+(.*)$")
    if subcmd_key and subcmd_arg_lead and subcommands[subcmd_key] and subcommands[subcmd_key].complete then
      return subcommands[subcmd_key].complete(subcmd_arg_lead)
    end
    -- Otherwise complete subcommand names
    if cmdline:match("^['<,'>]*" .. name .. "[!]*%s+%w*$") then
      return vim.iter(vim.tbl_keys(subcommands))
        :filter(function(key)
          return key:find(arg_lead) ~= nil
        end)
        :totable()
    end
    return {}
  end

  vim.api.nvim_create_user_command(name, dispatch, vim.tbl_extend("force", {
    nargs = "+",
    desc = name .. " command",
    complete = complete,
  }, opts))
end

return M
