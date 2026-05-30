# arm-fold-vim

Vim folding for arms in Hoon cores.

The plugin sets `foldmethod=expr` for Hoon buffers. Each `++`, `+$`, or `+*`
arm header remains visible while its body folds through the line before the
next sibling arm or the core's terminating `--`. Nested `|_`, `|%`, `|^`, and
`|@` cores add nested fold levels when they appear inside an arm. One-line arm
bodies are folded as well.

## Installation

Replace `YOUR_USERNAME` with the GitHub account that owns the repository.

### vim-plug

Add this to `.vimrc` or `init.vim`:

```vim
Plug 'YOUR_USERNAME/arm-fold-vim'
```

Then run `:PlugInstall`.

### lazy.nvim

Add this to your Neovim plugin spec:

```lua
{
  "YOUR_USERNAME/arm-fold-vim",
  ft = "hoon",
}
```

Then run `:Lazy sync`.

### packer.nvim

Add this to your Neovim plugin specification:

```lua
use "YOUR_USERNAME/arm-fold-vim"
```

Then run `:PackerSync`.

### Native Packages

For Neovim:

```sh
git clone https://github.com/YOUR_USERNAME/arm-fold-vim.git \
  ~/.local/share/nvim/site/pack/plugins/start/arm-fold-vim
```

For Vim:

```sh
git clone https://github.com/YOUR_USERNAME/arm-fold-vim.git \
  ~/.vim/pack/plugins/start/arm-fold-vim
```

The plugin includes fallback `.hoon` filetype detection.

## Usage

To open all folds in the current buffer, run `zR`.

With the cursor on an arm header, press `za` to cycle through:

1. The arm body folded.
2. The arm body visible with direct sub-arm bodies folded.
3. The full arm body recursively open.

The `:ArmFoldToggle` command performs the same action. Put the cursor on a
visible sub-arm header and use `za` to toggle that arm independently. On lines
other than arm headers, `za` keeps its standard Vim behavior.

Hoon buffers start in an outline view: nested arm headers remain visible while
ordinary content runs and leaf arm bodies are folded. Run `:ArmFoldShallow` to
restore that view after changing folds manually.

The parser follows Hoon's two-space arm indentation convention. Same-column
comments before an arm stay with that following arm instead of folding into
the preceding arm body. It also supports a first arm declared on the core rune
line, such as `|%  +$  typ`. Core openers and terminators remain visible in
outline mode.

Neovim uses a Lua parser fast path for large Hoon files. Vim uses the matching
Vimscript implementation.

Run the focused test with:

```sh
vim -Nu NONE -i NONE -n -es -S test/arm_fold.vim
vim -Nu NONE -i NONE -n -es -S test/open_file.vim
```
