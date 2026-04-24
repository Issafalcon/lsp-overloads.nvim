--- Tests for the :LspOverloads user command

describe("LspOverloads command", function()
  it("is registered as a user command", function()
    local cmds = vim.api.nvim_get_commands({})
    assert.is_not_nil(cmds["LspOverloads"], "expected :LspOverloads command to exist")
  end)

  it("does not error when called with 'toggle'", function()
    local ok, err = pcall(vim.api.nvim_command, "LspOverloads toggle")
    assert.is_true(ok, tostring(err))
  end)

  it("does not error when called with 'signature'", function()
    -- signature_help may fail in a headless busted environment (no LSP attached)
    -- but the dispatch itself should not throw an unknown-subcommand error
    local ok, err = pcall(vim.api.nvim_command, "LspOverloads signature")
    -- Allow "no LSP client attached" type errors but not dispatch errors
    if not ok then
      -- A dispatch error would contain "Unknown subcommand" — fail if so
      assert.falsy(tostring(err):find("Unknown subcommand", 1, true), err)
    end
  end)

  it("reports an error for unknown subcommands", function()
    local ok, err = pcall(vim.api.nvim_command, "LspOverloads unknown_subcmd")
    assert.is_false(ok)
    assert.truthy(tostring(err):find("Unknown subcommand", 1, true), err)
  end)

  it("provides tab-completion for known subcommands", function()
    local completion = vim.fn.getcompletion("LspOverloads ", "cmdline")
    assert.truthy(vim.tbl_contains(completion, "signature"), "expected 'signature' in completions")
    assert.truthy(vim.tbl_contains(completion, "toggle"), "expected 'toggle' in completions")
  end)
end)
