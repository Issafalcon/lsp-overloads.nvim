--- :checkhealth lsp-overloads
--- Verifies that lsp-overloads.nvim is correctly installed and configured.

local M = {}

local function check_nvim_version()
  vim.health.start("Neovim version")
  local version = vim.version()
  if version.major > 0 or version.minor >= 11 then
    vim.health.ok(("Neovim %d.%d.%d (>= 0.11 required)"):format(version.major, version.minor, version.patch))
  else
    vim.health.error(
      ("Neovim %d.%d.%d detected — lsp-overloads requires 0.11+"):format(version.major, version.minor, version.patch),
      "Upgrade Neovim to at least version 0.11"
    )
  end
end

local function check_handler()
  vim.health.start("LSP handler")
  local handler = vim.lsp.handlers["textDocument/signatureHelp"]
  if handler then
    -- Try to detect if it's our handler
    local info = debug.getinfo(handler, "S")
    local source = info and info.source or ""
    if source:find("lsp-overloads", 1, true) then
      vim.health.ok("lsp-overloads handler is installed as the global signatureHelp handler")
    else
      vim.health.warn("A signatureHelp handler is installed but it does not appear to be lsp-overloads", {
        "If you called setup() with override_native_handler=true (the default), this should resolve itself.",
        "If you have another plugin (e.g. noice.nvim) overriding this handler after setup(), see the README.",
      })
    end
  else
    vim.health.warn(
      "No signatureHelp handler is installed",
      "Call require('lsp-overloads').setup() to install the handler"
    )
  end
end

local function check_conflicting_plugins()
  vim.health.start("Conflicting plugins")
  local conflicts = {
    { module = "lsp_signature", name = "lsp_signature.nvim" },
    { module = "noice", name = "noice.nvim (check its LSP signature config)" },
  }
  local found_any = false
  for _, plugin in ipairs(conflicts) do
    local ok = pcall(require, plugin.module)
    if ok then
      found_any = true
      vim.health.warn(
        plugin.name .. " is loaded — it may conflict with lsp-overloads",
        "See README section 'Avoiding duplicate signature popups' for configuration guidance"
      )
    end
  end
  if not found_any then
    vim.health.ok("No known conflicting plugins detected")
  end
end

local function check_config()
  vim.health.start("Configuration")
  local ok, configuration = pcall(require, "lsp-overloads._core.configuration")
  if not ok then
    vim.health.error("Could not load lsp-overloads configuration module")
    return
  end
  local cfg = configuration.current
  vim.health.ok(("display_automatically = %s"):format(tostring(cfg.display_automatically)))
  vim.health.ok(("override_native_handler = %s"):format(tostring(cfg.override_native_handler)))
  vim.health.ok(("ui.border = %q"):format(cfg.ui.border))
  vim.health.ok(("ui.zindex = %d"):format(cfg.ui.zindex))
end

function M.check()
  check_nvim_version()
  check_handler()
  check_conflicting_plugins()
  check_config()
end

return M
