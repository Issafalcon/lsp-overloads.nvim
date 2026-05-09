--- Tests for lsp-overloads._lsp.content

local content = require("lsp-overloads._lsp.content")

--- Helper: minimal signatureHelp result with one signature
local function make_help(overrides)
  return vim.tbl_deep_extend("force", {
    signatures = {
      {
        label = "foo(a: string, b: number): void",
        parameters = {
          { label = "a: string" },
          { label = "b: number" },
        },
      },
    },
    activeSignature = 0,
    activeParameter = 0,
  }, overrides or {})
end

describe("content.to_markdown_lines()", function()
  it("returns nil when signatures is absent", function()
    local lines, hl = content.to_markdown_lines({}, nil, nil)
    assert.is_nil(lines)
    assert.is_nil(hl)
  end)

  it("returns nil for nil input", function()
    local lines, hl = content.to_markdown_lines(nil, nil, nil)
    assert.is_nil(lines)
    assert.is_nil(hl)
  end)

  it("includes the signature label", function()
    local lines, _ = content.to_markdown_lines(make_help(), nil, nil)
    assert.is_not_nil(lines)
    local full = table.concat(lines, "\n")
    assert.truthy(full:find("foo(a: string, b: number): void", 1, true))
  end)

  it("wraps label in a code fence when filetype is provided", function()
    local lines, _ = content.to_markdown_lines(make_help(), "typescript", nil)
    assert.is_not_nil(lines)
    assert.equal("```typescript", lines[1])
  end)

  it("does NOT include overload count for a single signature", function()
    local lines, _ = content.to_markdown_lines(make_help(), nil, nil)
    assert.is_not_nil(lines)
    local full = table.concat(lines, "\n")
    assert.falsy(full:find("Overload", 1, true))
  end)

  it("includes overload count for multiple signatures", function()
    local help = make_help({
      signatures = {
        { label = "foo(a: string): void", parameters = { { label = "a: string" } } },
        {
          label = "foo(a: string, b: number): void",
          parameters = { { label = "a: string" }, { label = "b: number" } },
        },
      },
    })
    local lines, _ = content.to_markdown_lines(help, nil, nil)
    assert.is_not_nil(lines)
    local full = table.concat(lines, "\n")
    assert.truthy(full:find("Overload 1 of 2", 1, true))
  end)

  it("clips out-of-range activeSignature to 0", function()
    local help = make_help({ activeSignature = 99 })
    local lines, _ = content.to_markdown_lines(help, nil, nil)
    assert.is_not_nil(lines)
  end)

  it("clips negative activeSignature to 0", function()
    local help = make_help({ activeSignature = -1 })
    local lines, _ = content.to_markdown_lines(help, nil, nil)
    assert.is_not_nil(lines)
  end)

  it("returns active_hl when parameter label is a string", function()
    -- "a: string" is at offset 4 in "foo(a: string, b: number): void"
    local help = make_help({ activeParameter = 0 })
    local _, hl = content.to_markdown_lines(help, nil, { "(" })
    assert.is_not_nil(hl)
    assert.equal(2, #hl) -- { start_col, end_col }
  end)

  it("uses table parameter label directly as active_hl", function()
    local help = make_help()
    help.signatures[1].parameters[1].label = { 4, 12 }
    local _, hl = content.to_markdown_lines(help, nil, nil)
    assert.same({ 4, 12 }, hl)
  end)

  it("includes parameter documentation when present", function()
    local help = make_help()
    help.signatures[1].parameters[1].documentation = { kind = "plaintext", value = "The first arg" }
    local lines, _ = content.to_markdown_lines(help, nil, nil)
    assert.is_not_nil(lines)
    local full = table.concat(lines, "\n")
    assert.truthy(full:find("The first arg", 1, true))
  end)
end)

describe("content.render()", function()
  it("returns empty content when state has no signatures", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local state = {
      signatures = nil,
      activeSignature = 0,
      activeParameter = nil,
      ctx = { client_id = nil, bufnr = bufnr, method = "test" },
      config = {},
      mode = "i",
      bufnr = bufnr,
      fwin = nil,
      fbuf = nil,
      content = {},
      _buf_mappings = {},
      _original_mappings = {},
    }
    -- Stub vim.lsp.get_client_by_id to return nil
    local orig = vim.lsp.get_client_by_id
    vim.lsp.get_client_by_id = function()
      return nil
    end
    local result = content.render(state)
    vim.lsp.get_client_by_id = orig
    assert.is_nil(result.contents)
  end)
end)
