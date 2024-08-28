local M = {
  "EthanJWright/vs-tasks.nvim",
  dependencies = {
    "nvim-lua/popup.nvim",
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  event = "VeryLazy",
}

function M.config()
  local wk = require "which-key"
  wk.add {
    { "<leader>rh", "<cmd>lua require('telescope').extensions.vstask.history()<cr>", desc = "Task History" },
    { "<leader>ri", "<cmd>lua require('telescope').extensions.vstask.inputs()<cr>", desc = "Task Inputs" },
    { "<leader>rl", "<cmd>lua require('telescope').extensions.vstask.launch()<cr>", desc = "Task Launch" },
    { "<leader>rt", "<cmd>lua require('telescope').extensions.vstask.tasks()<cr>", desc = "Tasks" },
  }
  require("vstask").setup {}
end

return M
