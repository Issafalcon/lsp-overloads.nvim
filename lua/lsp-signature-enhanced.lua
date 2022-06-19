---@module "lsp-signature-enhanced.settings"
local settings = require("lsp-signature-enhanced.settings")
local M = {}

---@param config LspSignatureEnhancedSettings
function M.setup(config)
    if config then
        settings.set(config)
    end
end

return M
