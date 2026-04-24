return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      -- Show the current working directory name in lualine section Y
      table.insert(opts.sections.lualine_y, 1, {
        function()
          return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
        end,
        icon = "",
        color = { fg = "#ff9e64", gui = "bold" },
      })
    end,
  },
}
