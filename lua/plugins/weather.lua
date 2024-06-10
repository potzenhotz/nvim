return {
  "lazymaniac/wttr.nvim",
  event = "VeryLazy",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
  },
  opts = {
    location = "Dortmund",
    format = 4,
    custom_format = "%C+%cP:%p+T:%t+F:%f+%w+%m+%P+UV:%u+Hum:%h",
  },
  keys = {
    {
      "<leader>v",
      function()
        require("wttr").get_forecast() -- show forecast for my location
      end,
      desc = "Weather Forecast",
    },
    {
      "<leader>V",
      function()
        require("wttr").get_forecast("Frankfurt") -- show forecast for London
      end,
      desc = "Weather Forecast - London",
    },
  },
}
