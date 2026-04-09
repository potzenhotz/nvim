return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        python = { "ruff_format" },
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = false },
      servers = {
        pyright = { enabled = false },
        ruff_lsp = { enabled = false },
        basedpyright = {
          enabled = true,
          settings = {
            basedpyright = {
              typeCheckingMode = "standard",
            },
          },
        },
        ruff = {},
      },
    },
  },
}
