return {
  {
    "craftzdog/solarized-osaka.nvim",
    lazy = true,
    priority = 1000,
    opts = function()
      return {
        transparent = true,
      }
    end,
  },
  {
    "folke/tokyonight.nvim",
    lazy = true,
    priority = 1001,
  },
  {
    "catppuccin/nvim",
    lazy = true,
    priority = 1002,
    name = "catppuccin",
  },
  { "rebelot/kanagawa.nvim", lazy = true },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "kanagawa-wave",
    },
  },
}
