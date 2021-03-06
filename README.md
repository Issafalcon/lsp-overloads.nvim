# LSP Overloads Nvim

Extends the built-in Neovim LSP signature helper handler to add additional functionality, focussing on enhancements
for method overloads.

https://user-images.githubusercontent.com/19861614/177287518-c3ea1d15-75b7-4abc-b5c9-6f99c83dd0e0.mp4

## Rationale

- Native LSP signatureHelper handler doesn't provide an easy way to view all the possible overloads and parameter details for signatures
- Other Neovim LSP plugins either don't support method overloads in the signatureHelper popup view, or don't focus specifically on method overloads
and are therefore lacking in the functionality I wanted from handling multiple signatures

## Requirements

- Neovim ≥ 0.7.0

## Installation

Install the plugin with the package manager of choice:

```lua
--Packer
use { 'Issafalcon/lsp-overloads.nvim'}
```

## Configuration

Within your custom `on-attach` function that you provide as part of the options to the LSP server, setup the plugin, which will override 
the built-in `signatureHelper` LSP handler:

<p>
<details>
<summary style='cursor: pointer'><b>Example without option overrides</b></summary>

```lua
  --- Guard against servers without the signatureHelper capability
  if client.server_capabilities.signatureHelpProvider then
    require('lsp-overloads').setup(client, { })
  end
```

</details>
</p>

<p>
<details>
<summary style='cursor: pointer'><b>Example with option overrides (defaults shown)</b></summary>

```lua
  --- Guard against servers without the signatureHelper capability
  if client.server_capabilities.signatureHelpProvider then
    require('lsp-overloads').setup(client, {
        ui = {
          -- The border to use for the signature popup window. Accepts same border values as |nvim_open_win()|.
          border = "single"
        },
        keymaps = {
          next_signature = "<C-j>",
          previous_signature = "<C-k>",
          next_parameter = "<C-l>",
          previous_parameter = "<C-h>",
        },
      })
  end
```

</details>
</p>

## Usage

LSP trigger characters will cause the signature popup to be displayed. If there are any overloads, the popup will indicate this is the case and
you will be able to navigate between the overloads.

Regardless of whether or not overloads exist, you will also be able to navigate between the paramters which will change the content of the signature popup to display
the details of the highlighted paramter.

### Toggling Signature Overload and Parameters

The default mappings are used to navigate between various signature overloads and parameters when the signature popup is displayed:
- `next_signature = "<C-j>"`
- `previous_signature = "<C-k>"`
- `next_parameter = "<C-l>"`
- `previous_parameter = "<C-h>"`

### Additional Tips

- Any calls to `vim.lsp.buf.signature_help()` made while the plugin's signature popup is displayed, will behave
in the same way as the built-in signature popup (i.e. Cursor will enter the popup in normal mode, allowing scrolling behaviour)

## Feature Roadmap

  | Feature   | Status    |
  |--------------- | --------------- |
  | Overload Toggle   | :white_check_mark:   |
  | Parameter Toggle   | :white_check_mark:   |
  | Parameter Highlights in Signature Content Text   | :black_square_button:   |
  | Plugin command to trigger the custom signature request manually | :black_square_button:   |
  | Scrolling signature popup content without entering popup window   | :black_square_button:   |
  | UI: Border customisation   | :white_check_mark:   |
  | UI: Popup position customisation   | :black_square_button:   |


## Credits

- [omnisharp-vim](https://github.com/OmniSharp/omnisharp-vim/blob/master/autoload/OmniSharp/actions/signature.vim) - For providing the approach that I used to handle the signature overloads and keymappings
- [lsp_signature.nvim](https://github.com/ray-x/lsp_signature.nvim) - The fully featured LSP signature enhancement plugin that I took inspiration from for this plugin
- [seblj dotfiles](https://github.com/seblj/dotfiles/blob/master/nvim/lua/config/lspconfig/signature.lua) - The starter code I used in this plugin to kick off the signature request
- [Neovim core codebase](https://github.com/neovim/neovim/blob/1a20aed3fb35e00f96aa18abb69d35912c9e119d/runtime/lua/vim/lsp/handlers.lua#L382) - The handler code that has been modified for this plugin
