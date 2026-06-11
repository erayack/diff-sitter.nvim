# diff-sitter.nvim

Semantic Tree-sitter highlighting for code inside unified diff, patch, and verbose Git commit buffers.

`diff-sitter.nvim` highlights the code portions of diff hunks while leaving the original buffer text untouched. It is intended for reviewing `.diff` / `.patch` files and verbose Git commit buffers directly in Neovim.

## Requirements

- Neovim 0.10+
- Tree-sitter parsers installed for the languages you want highlighted
- No `tree-sitter-diff` parser is required

If a target language parser is missing, that file/hunk is skipped silently.

## Installation

Use your preferred plugin manager. Example with lazy.nvim:

```lua
{
  "your-name/diff-sitter.nvim",
  config = function()
    require("diff-sitter").setup()
  end,
}
```

## Configuration

Defaults:

```lua
require("diff-sitter").setup({
  enabled = true,
  filetypes = { "diff", "patch", "gitcommit" },
  debounce_ms = 100,
  max_hunk_lines = 400,
  max_buffer_lines = 20000,
  debug = false,
})
```

The plugin automatically attaches to `diff`, `patch`, and `gitcommit` filetypes when enabled.

## Commands

- `:DiffSitterEnable` — enable highlighting for the current buffer
- `:DiffSitterDisable` — disable highlighting and clear plugin extmarks for the current buffer
- `:DiffSitterRefresh` — recompute highlights for the current buffer