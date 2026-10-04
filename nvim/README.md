# Neovim config

[LazyVim](https://lazyvim.org) with a small number of deliberate additions.
The guiding rule is that LazyVim's defaults win unless there is a reason to
differ, so this directory stays small and upstream improvements arrive for free.

## Layout

```
init.lua                  bootstraps lua/config/lazy.lua
lua/config/
  options.lua             background=light (for Latte) + cursor style
  keymaps.lua             empty -- LazyVim's defaults are the keymap
  autocmds.lua            BitBake filetypes for Yocto
  lazy.lua                plugin-manager bootstrap
lua/plugins/
  colorscheme.lua         Catppuccin Latte
  lsp.lua                 shell support (bashls + shfmt)
  lint.lua                Markdown + TeX linting
lint/                     markdownlint + vale configs
```

Everything else comes from LazyVim extras, listed in `lazyvim.json`: C/C++,
Python, Rust, CMake, Docker, YAML, JSON, TOML, Markdown, Git, neo-tree,
telescope, mini-surround, dap, Copilot and Claude Code.

## Learning the keymaps

There is no custom keymap layer. Everything is LazyVim's, which means the
official cheatsheet applies and so does every tutorial written for it.

- Press `<Space>` and wait — which-key lists what is available, by prefix.
- `<leader>sk` — fuzzy-search every active mapping (this is the ground truth;
  it includes each plugin's own keys).
- `:verbose nmap <C-s>` — shows a mapping *and the file that set it*, which is
  the fastest way to answer "why does this key do that?".

Debugging is on `<leader>d`, git on `<leader>g`, search on `<leader>s`,
find/files on `<leader>f`, LSP actions on `<leader>c`.

## Notes

`vim.opt.background = "light"` in `options.lua` is load-bearing for the theme,
not cosmetic — `lua/plugins/colorscheme.lua` explains why.

Two settings outside this directory support it:

- `~/.zshrc` — `stty -ixon`, so the terminal stops eating `Ctrl+S` as XOFF.
  LazyVim binds `Ctrl+S` to save, so without this the pane appears to freeze.
- `~/.tmux.conf` — `extended-keys on`, which lets modified key chords reach
  nvim. Optional now, harmless to keep.

## Requirements

Installed: `rg`, `fd` (symlink to Ubuntu's `fdfind`), `git`, `node`, `python3`,
`gcc`, `make`, `unzip`, `curl`, `cargo`, `rust-analyzer`, `lazygit`, `xclip`.

`chktex` is referenced by `lint/` for TeX and is not installed
(`sudo apt install chktex` if you ever edit `.tex`).
