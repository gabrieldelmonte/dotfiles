-- Catppuccin Latte, matching ~/.config/alacritty/catppuccin-latte.toml and the
-- tmux status bar.
--
-- The `config` function and `background` map below are not boilerplate. The
-- plugin's colors/catppuccin.lua is literally `require("catppuccin").load()`,
-- and if that runs before lazy.nvim has called setup() with these opts, the
-- flavour is still the default "auto" -- so load() picks it from
-- `vim.o.background` and then nils the option out, commented upstream as
-- "ensure that this will only run once on startup". Setting `flavour` alone is
-- not enough; it can arrive after the decision has already been made. Hence
-- also `vim.opt.background = "light"` in lua/config/options.lua.

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    lazy = false,
    opts = {
      flavour = "latte",
      background = { light = "latte", dark = "latte" },
      -- Let the Alacritty background (opacity 0.85) show through instead of
      -- painting Latte's base colour over it.
      transparent_background = true,
      term_colors = true,
      integrations = {
        -- LazyVim's own catppuccin spec already turns on the integrations for
        -- neo-tree, telescope, which-key, gitsigns, blink, snacks, noice,
        -- notify, mini, mason, trouble and flash. These two are the ones it
        -- does not cover.
        dap = true,
        dap_ui = true,
      },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin")
    end,
  },

  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "catppuccin" },
  },
}
