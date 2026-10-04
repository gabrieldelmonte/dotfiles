-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Catppuccin Latte is a light theme, and this has to be set before any plugin
-- loads: catppuccin resolves its flavour from `background` when its setup() has
-- not run yet, and only gets one chance to do so. See lua/plugins/colorscheme.lua.
vim.opt.background = "light"

-- Horizontal bar cursor in every mode, matching the Alacritty cursor style.
vim.opt.guicursor = "a:hor20"

-- Never hide markup. LazyVim defaults conceallevel to 2, which hides things
-- like ``` fences, [](link) brackets and emphasis markers, showing them again
-- only on the cursor line. Colours come from treesitter and are unaffected --
-- this only stops characters from being swallowed.
--
-- This covers .mdx and every other filetype. Plain .md needs a second setting,
-- because render-markdown.nvim overrides the window option while it renders;
-- see lua/plugins/markdown.lua.
vim.opt.conceallevel = 0
