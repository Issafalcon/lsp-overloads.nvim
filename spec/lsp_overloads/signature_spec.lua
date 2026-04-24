--- Tests for lsp-overloads._lsp.signature (state model)

local signature = require("lsp-overloads._lsp.signature")

--- Build a minimal SignatureState without needing a real LSP response
local function make_state(overrides)
  local base = {
    signatures = {
      {
        label = "foo(a: string): void",
        parameters = { { label = "a: string" } },
      },
      {
        label = "foo(a: string, b: number): void",
        parameters = { { label = "a: string" }, { label = "b: number" } },
      },
    },
    activeSignature = 0,
    activeParameter = 0,
    err = nil,
    ctx = { client_id = 1, bufnr = 1, method = "textDocument/signatureHelp" },
    config = {},
    mode = "i",
    bufnr = vim.api.nvim_get_current_buf(),
    fwin = nil,
    fbuf = nil,
    content = {},
    _buf_mappings = {},
    _original_mappings = {},
  }
  return vim.tbl_deep_extend("force", base, overrides or {})
end

describe("signature.modify_active_signature()", function()
  it("moves forward one step", function()
    local state = make_state()
    signature.modify_active_signature(state, 1)
    assert.equal(1, state.activeSignature)
  end)

  it("moves backward one step", function()
    local state = make_state({ activeSignature = 1 })
    signature.modify_active_signature(state, -1)
    assert.equal(0, state.activeSignature)
  end)

  it("does not go below 0", function()
    local state = make_state({ activeSignature = 0 })
    signature.modify_active_signature(state, -1)
    assert.equal(0, state.activeSignature)
  end)

  it("does not exceed the last signature index", function()
    local state = make_state({ activeSignature = 1 })
    signature.modify_active_signature(state, 1)
    assert.equal(1, state.activeSignature)
  end)

  it("is a no-op when there is only one signature", function()
    local state = make_state()
    state.signatures = { state.signatures[1] }
    signature.modify_active_signature(state, 1)
    assert.equal(0, state.activeSignature)
  end)

  it("persists selection in a buffer variable", function()
    local state = make_state()
    signature.modify_active_signature(state, 1)
    local persisted = vim.api.nvim_buf_get_var(state.bufnr, "lsp_overloads_active_sig")
    assert.equal(1, persisted)
  end)
end)

describe("signature.modify_active_param()", function()
  it("advances the per-signature activeParameter", function()
    local state = make_state()
    -- Use second signature (index 1, 2 parameters) so advancement is possible
    state.activeSignature = 1
    state.signatures[2].activeParameter = 0
    signature.modify_active_param(state, 1)
    assert.equal(1, state.signatures[2].activeParameter)
  end)

  it("does not advance past the last parameter", function()
    local state = make_state()
    state.signatures[1].activeParameter = 0
    -- Only 1 parameter — can't go to index 1
    signature.modify_active_param(state, 1)
    assert.equal(0, state.signatures[1].activeParameter)
  end)

  it("falls back to root activeParameter when per-sig one is absent", function()
    local state = make_state({ activeParameter = 0 })
    state.signatures[1].activeParameter = nil
    signature.modify_active_param(state, 1)
    -- Second signature has 2 params — root activeParam can advance
    -- (uses signatures[activeSignature+1] which is signatures[1] with 1 param → no-op)
    assert.equal(0, state.activeParameter)
  end)

  it("initialises activeParameter = 0 when not set and advances", function()
    local state = make_state()
    -- Use signature index 1 (2 parameters)
    state.activeSignature = 1
    state.activeParameter = nil
    state.signatures[2].activeParameter = nil
    signature.modify_active_param(state, 1)
    -- After initialisation, param should be at 1
    assert.equal(1, state.signatures[2].activeParameter)
  end)
end)

describe("signature overload preservation", function()
  it("new() restores persisted activeSignature from buffer variable", function()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_var(bufnr, "lsp_overloads_active_sig", 1)

    local result = {
      signatures = {
        { label = "foo(a: string): void" },
        { label = "foo(a: string, b: number): void" },
      },
      activeSignature = 0, -- server always sends 0
      activeParameter = nil,
    }
    local state = signature.new(result, nil, { client_id = 1, bufnr = bufnr, method = "test" }, {})
    -- User's persisted choice (1) should override server's (0)
    assert.equal(1, state.activeSignature)

    -- Cleanup
    signature.clear_persisted_selection(bufnr)
  end)

  it("new() ignores persisted index if out of bounds", function()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_var(bufnr, "lsp_overloads_active_sig", 99)

    local result = {
      signatures = {
        { label = "foo(): void" },
      },
      activeSignature = 0,
      activeParameter = nil,
    }
    local state = signature.new(result, nil, { client_id = 1, bufnr = bufnr, method = "test" }, {})
    assert.equal(0, state.activeSignature)

    signature.clear_persisted_selection(bufnr)
  end)
end)

describe("signature.clear_persisted_selection()", function()
  it("removes the buffer variables without error", function()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_var(bufnr, "lsp_overloads_active_sig", 1)
    vim.api.nvim_buf_set_var(bufnr, "lsp_overloads_swapping", 42)
    assert.has_no.errors(function()
      signature.clear_persisted_selection(bufnr)
    end)
    assert.is_nil(vim.F.npcall(vim.api.nvim_buf_get_var, bufnr, "lsp_overloads_active_sig"))
  end)

  it("does not error when variables do not exist", function()
    local bufnr = vim.api.nvim_get_current_buf()
    assert.has_no.errors(function()
      signature.clear_persisted_selection(bufnr)
    end)
  end)
end)
