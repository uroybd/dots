local M = {
  "folke/trouble.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  event = "VeryLazy",
}

M.config = function()
  local wk = require "which-key"

  wk.add {
    { "<leader>dt", "<cmd>TroubleToggle<CR>", desc = "Trouble" },
    { "<leader>dd", "<cmd>TroubleToggle document_diagnostics<CR>", desc = "Document Diagnostics", icon = "󱪗" },
    { "<leader>dw", "<cmd>TroubleToggle workspace_diagnostics<CR>", desc = "Workspace Diagnostics", icon = "󰷌" },
    { "<leader>dr", "<cmd>TroubleToggle lsp_references<CR>", desc = "References" },
    { "<leader>dq", "<cmd>TroubleToggle quickfix<CR>", desc = "Quickfix" },
  }

  require("trouble").setup {
    position = "bottom",
    height = 15,
    icons = true,
    mode = "workspace_diagnostics",
    group = true,
    padding = true,
  }
end

return M
