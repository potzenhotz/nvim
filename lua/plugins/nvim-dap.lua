return {
  "mfussenegger/nvim-dap",
  opts = {
    dap = {
      configurations = {
        python = {
          {
            type = "python",
            request = "launch",
            name = "Launch file",
            program = "${file}",
            justMyCode = false, -- Set justMyCode to false
          },
        },
      },
    },
  },
}
