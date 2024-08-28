local M = {
  "olrtg/nvim-emmet",
  ft = { "html", "css" },
}

M.config = function()
  local wk = require "which-key"
  wk.register {
    ["<leader>xe"] = { "<cmd>require('nvim-emmet').wrap_with_abbreviation<cr>", "Emmet Wrap with Abbreviation" },
  }
end

return M
