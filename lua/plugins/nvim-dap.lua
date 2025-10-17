return {
  "mfussenegger/nvim-dap",
  config = function()
    local dap = require("dap")
    dap.configurations.python = {
      {
        justMyCode = false,
        type = "python",
        request = "launch",
        name = "Launch file",
        program = "${file}",
        console = "integratedTerminal",
      },
    }
  end,
}
