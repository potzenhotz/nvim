return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      pyright = {
        settings = {
          python = {
            venvPath = ".",
            venv = ".venv",
          },
        },
      },
      yamlls = {
        settings = {
          yaml = {
            format = {
              bracketSpacing = false,
            },
          },
        },
      },
    },
  },
}
