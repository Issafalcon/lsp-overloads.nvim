---@class SignatureContent
---@field contents table | nil The contents of the signature
---@field active_hl table | nil The active highlight of the signature
---@field add_content function Adds the contents of the signature to the signature content object

---@class Signature
---@field err table | nil The error message
---@field mode string The current mode
---@field ctx table The context
---@field config table The configuration
---@field signatures table The signatures
---@field signature_content SignatureContent The signature content