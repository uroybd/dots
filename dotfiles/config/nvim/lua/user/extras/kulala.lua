local M = {
  'mistweaverco/kulala.nvim',
  
}

function M.config()
  local kl = require("kulala");
  kl.setup({
    winbar = true,
    default_winbar_panes = { "body", "headers", "headers_body", "script_output" },
  })
  
  vim.filetype.add({
    extension = {
      http = "http",
    },
  })

  local wk = require("which-key");

  wk.add({
    {"<leader>k", group = "Kulala"},
    {"<leader>kr", kl.run, desc = "Run" },
    {"<leader>ka", kl.run_all, desc = "Run All" },
    {"<leader>ki", kl.inspect, desc = "Inspect"},
    {"<leader>ks", kl.search, desc = "Search"},
    {"<leader>kS", kl.show_stats, desc = "Statistics"},
    {"<leader>kc", kl.close, desc = "Close"},
    {"<leader>kt", kl.toggle_view, desc = "Toggle"},
    {"<leader>kG", kl.download_graphql_schema, desc = "Download GraphQL Schema"},
    {"<leader>kj", kl.jump_next, desc = "Next"},
    {"<leader>kk", kl.jump_prev, desc = "Prev"},
  })
end

return M
