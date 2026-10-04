-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- BitBake recipes, for Yocto work. Neovim has no built-in filetype for these.
vim.filetype.add({
  extension = {
    bb = "bitbake",
    bbappend = "bitbake",
    bbclass = "bitbake",
  },
  filename = {
    ["local.conf"] = "bitbake",
    ["bblayers.conf"] = "bitbake",
  },
})
