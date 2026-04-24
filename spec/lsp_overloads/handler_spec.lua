--- Tests for lsp-overloads._lsp.handler

local handler = require("lsp-overloads._lsp.handler")
local configuration = require("lsp-overloads._core.configuration")

describe("handler.handler()", function()
  before_each(function()
    configuration.reset()
  end)

  -- The handler guards on result==nil, not on err
  it("returns nil when result is nil", function()
    local result = handler.handler(
      nil,
      nil,
      { client_id = 1, bufnr = 1, method = "textDocument/signatureHelp" },
      {}
    )
    assert.is_nil(result)
  end)

  it("returns nil when signatures table is missing", function()
    local result = handler.handler(
      nil,
      {},
      { client_id = 1, bufnr = 1, method = "textDocument/signatureHelp" },
      {}
    )
    assert.is_nil(result)
  end)

  it("returns nil when signatures table is empty", function()
    local result = handler.handler(
      nil,
      { signatures = {} },
      { client_id = 1, bufnr = 1, method = "textDocument/signatureHelp" },
      {}
    )
    assert.is_nil(result)
  end)

  it("does not crash when result is nil and silent=false", function()
    -- Direct field assignment to avoid any tbl_deep_extend edge cases with bool false
    configuration.current.ui.silent = false
    local ok, err = pcall(handler.handler, nil, nil, { client_id = 1, bufnr = 1, method = "textDocument/signatureHelp" }, {})
    assert.is_true(ok, tostring(err))
  end)

  it("does NOT notify when result is nil and silent=true (config default)", function()
    -- Default: ui.silent = true
    local notified = false
    local orig_notify = vim.notify
    vim.notify = function(msg, _)
      if msg:find("lsp-overloads") then
        notified = true
      end
    end
    handler.handler(nil, nil, { client_id = 1, bufnr = 1, method = "textDocument/signatureHelp" }, {})
    vim.notify = orig_notify
    assert.is_false(notified)
  end)
end)

describe("handler.check_inside_call()", function()
  -- check_inside_call(line_to_cursor) — single argument
  it("returns false when line has no open paren", function()
    assert.is_false(handler.check_inside_call(""))
    assert.is_false(handler.check_inside_call("foo"))
  end)

  it("returns true when exactly one unmatched open paren exists", function()
    -- "foo(" → 1 open, 0 close → 1 == 0+1 → true
    assert.is_true(handler.check_inside_call("foo("))
  end)

  it("returns true for nested calls (multiple unmatched opens)", function()
    -- open=2, close=0 → 2 > 0 → true
    assert.is_true(handler.check_inside_call("bar(foo(a, "))
  end)

  it("returns false when parens are balanced (call completed)", function()
    -- "foo(a)" → 1 open, 1 close → 1 == 1+1 = 2 → false
    assert.is_false(handler.check_inside_call("foo(a)"))
  end)

  it("returns false when there are more close parens than open", function()
    assert.is_false(handler.check_inside_call("foo)"))
  end)
end)
