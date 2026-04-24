<p align="center">
<a href="https://github.com/Issafalcon/lsp-overloads.nvim/actions/workflows/main.yml">
  <img alt="GitHub Workflow Status" src="https://img.shields.io/github/actions/workflow/status/Issafalcon/lsp-overloads.nvim/main.yml?label=main&style=for-the-badge">
</a>
<a href="https://github.com/Issafalcon/lsp-overloads.nvim/releases">
  <img alt="GitHub release (latest SemVer)" src="https://img.shields.io/github/v/release/Issafalcon/lsp-overloads.nvim?style=for-the-badge">
</a>
</p>

# LSP Overloads Nvim

Extends the built-in Neovim LSP signature helper handler to add additional functionality, focussing on enhancements
for method overloads.

https://user-images.githubusercontent.com/19861614/177287518-c3ea1d15-75b7-4abc-b5c9-6f99c83dd0e0.mp4

## Rationale

- Native LSP signatureHelper handler doesn't provide an easy way to view all the possible overloads and parameter details for signatures
- Other Neovim LSP plugins either don't support method overloads in the signatureHelper popup view, or don't focus specifically on method overloads
  and are therefore lacking in the functionality I wanted from handling multiple signatures

## Requirements

- Neovim ≥ 0.11

## Installation

```lua
-- lazy.nvim
{
  "Issafalcon/lsp-overloads.nvim",
  event = "LspAttach",
}

-- packer.nvim
use { "Issafalcon/lsp-overloads.nvim" }
```

## Configuration

Call `setup()` once in your Neovim config. The plugin automatically attaches to any LSP client that provides
`signatureHelpProvider` via a `LspAttach` autocommand — no per-server `on_attach` wiring required.

### Minimal setup (all defaults)

```lua
require("lsp-overloads").setup()
```

### Full setup with all options

```lua
require("lsp-overloads").setup({
  -- UI options — mostly match vim.lsp.util.open_floating_preview
  ui = {
    border = "single",        -- border style: "none","single","double","rounded","solid","shadow"
    height = nil,             -- nil = auto-size
    width = nil,              -- nil = auto-size
    wrap = true,
    wrap_at = nil,
    max_width = nil,
    max_height = nil,
    close_events = { "CursorMoved", "BufHidden", "InsertLeave" },
    focusable = true,
    focus = false,
    offset_x = 0,
    offset_y = 0,
    silent = true,            -- suppress "No signature help" messages
    floating_window_above_cur_line = false,
    zindex = 50,              -- z-index of the floating window
  },
  keymaps = {
    next_signature     = "<C-j>",
    previous_signature = "<C-k>",
    next_parameter     = "<C-l>",
    previous_parameter = "<C-h>",
    close_signature    = "<A-s>",
    scroll_down        = "<C-d>",   -- scroll the popup window down
    scroll_up          = "<C-u>",   -- scroll the popup window up
  },
  display_automatically    = true,  -- show popup on trigger characters automatically
  override_native_handler  = true,  -- replace vim.lsp.handlers["textDocument/signatureHelp"]
  log_level                = "warn",
})
```

### Manual `on_attach` (fine-grained control)

If you prefer to control exactly which buffers the plugin attaches to, set `override_native_handler = false` and
call `on_attach` yourself:

```lua
require("lsp-overloads").setup({ override_native_handler = false })

-- Inside your LSP on_attach:
local function on_attach(client, bufnr)
  if client.server_capabilities.signatureHelpProvider then
    require("lsp-overloads").on_attach(client, bufnr)
  end
end
```

---

## Migration from v1.x

The old API `require("lsp-overloads").setup(client, config)` (client as first arg) is no longer supported.

| Old (v1.x)                                     | New (v2.x)                              |
| ---------------------------------------------- | --------------------------------------- |
| `setup(client, config)` inside `on_attach`     | `setup(config)` once at startup         |
| Manual attach loop in every server             | Automatic via `LspAttach` autocmd       |
| `:LspOverloadsSignature`                       | `:LspOverloads signature`               |
| `:LspOverloadsSignatureAutoToggle`             | `:LspOverloads toggle`                  |
| No scroll keymaps                              | `scroll_down` / `scroll_up` (new)       |
| No `zindex` option                             | `ui.zindex` (new, default 50)           |

---

## Usage

### Triggering the Signature Popup

LSP trigger characters (typically `(` and `,`) will automatically display the signature popup when
`display_automatically = true` (the default).

To trigger manually from any mode, use the command:

```vim
:LspOverloads signature
```

Or map it to a key:

```lua
vim.keymap.set({ "n", "i" }, "<A-s>", "<cmd>LspOverloads signature<CR>", { silent = true })
```

### Toggling Automatic Display

```vim
:LspOverloads toggle
```

Or set `display_automatically = false` in your config to disable automatic display entirely.

### Keybinds (active while popup is open)

These keymaps are installed buffer-locally while the signature popup is visible, then removed or
restored to your original bindings when the popup closes.

| Key     | Action                         |
| ------- | ------------------------------ |
| `<C-j>` | Next overload signature        |
| `<C-k>` | Previous overload signature    |
| `<C-l>` | Next parameter                 |
| `<C-h>` | Previous parameter             |
| `<A-s>` | Close popup                    |
| `<C-d>` | Scroll popup down              |
| `<C-u>` | Scroll popup up                |

All keys are configurable via the `keymaps` table in `setup()`.

---

## Health Check

Run `:checkhealth lsp-overloads` to verify:
- Neovim version compatibility
- Whether the native handler override is installed
- Conflicting plugins that may cause duplicate popups

---

## Preventing Conflicting Signature Popups

Neovim 0.10+ and several plugins also hook into `textDocument/signatureHelp`. Having multiple handlers
active at once causes duplicate (or stacked) signature popups.

### Native Neovim handler

By default (`override_native_handler = true`), lsp-overloads replaces the native
`vim.lsp.handlers["textDocument/signatureHelp"]` on startup. This is the recommended setting.

If you explicitly want to keep the native handler, set `override_native_handler = false` and remove
the native handler yourself:

```lua
vim.lsp.handlers["textDocument/signatureHelp"] = nil  -- disable native popup
require("lsp-overloads").setup({ override_native_handler = false })
-- then call on_attach() manually per buffer
```

### noice.nvim

`noice.nvim` intercepts `textDocument/signatureHelp` by default. To route it to lsp-overloads instead:

```lua
require("noice").setup({
  lsp = {
    signature = {
      enabled = false,  -- disable noice's signature handler
    },
  },
})
require("lsp-overloads").setup()
```

### lsp_signature.nvim

Do not load both `lsp_signature.nvim` and `lsp-overloads.nvim` at the same time — they both override
the same global handler. Remove or disable `lsp_signature.nvim` if you use lsp-overloads.

### nvim-cmp

`nvim-cmp` has its own `cmp.config.sources` for signature help (`cmp-nvim-lsp-signature-help`). Disable
that source if it conflicts:

```lua
require("cmp").setup({
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    -- Remove or comment out: { name = "nvim_lsp_signature_help" }
  }),
})
```

### blink.cmp

In `blink.cmp`, disable the built-in signature popup:

```lua
require("blink.cmp").setup({
  signature = { enabled = false },
})
```

### Neovim 0.11+ `vim.lsp.config`

If you configure LSP servers via the new `vim.lsp.config` API, lsp-overloads' global handler override
takes effect automatically. No per-server wiring is needed.

---

## Debugging

If signatures aren't appearing when expected:

1. Set `ui.silent = false` in your config — the plugin will log "No signature help available" to the
   messages area, confirming the LSP response is empty rather than a plugin issue.
2. Run `:checkhealth lsp-overloads` to verify the handler is installed.
3. Confirm the LSP client reports `signatureHelpProvider` capability:
   ```lua
   :lua vim.print(vim.lsp.get_clients({ bufnr = 0 })[1].server_capabilities.signatureHelpProvider)
   ```

---

## Credits

- [omnisharp-vim](https://github.com/OmniSharp/omnisharp-vim/blob/master/autoload/OmniSharp/actions/signature.vim) — original approach for signature overloads and keymappings
- [lsp_signature.nvim](https://github.com/ray-x/lsp_signature.nvim) — inspiration
- [seblj dotfiles](https://github.com/seblj/dotfiles/blob/master/nvim/lua/config/lspconfig/signature.lua) — starter code
- [Neovim core codebase](https://github.com/neovim/neovim/blob/1a20aed3fb35e00f96aa18abb69d35912c9e119d/runtime/lua/vim/lsp/handlers.lua#L382) — original handler logic
- [lumen-oss/nvim-best-practices](https://github.com/lumen-oss/nvim-best-practices) — structural best-practices guide
- [ColinKennedy/nvim-best-practices-plugin-template](https://github.com/ColinKennedy/nvim-best-practices-plugin-template) — plugin template reference
