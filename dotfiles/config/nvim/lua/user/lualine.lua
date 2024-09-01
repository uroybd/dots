local M = {
  "nvim-lualine/lualine.nvim",
  dependencies = {
    "AndreM222/copilot-lualine",
  },
}

function M.config()
  require("lualine").setup {
    options = {
      component_separators = { left = "", right = "" },
      section_separators = { left = " ", right = " " },

      ignore_focus = { "NvimTree" },
      theme = "catppuccin",
    },
    sections = {
      lualine_a = { "mode" },
      lualine_b = {
        "branch",
        {
          "diff",
          symbols = {
            added = " ",
            modified = " ",
            removed = " ",
          },
        },
        "diagnostics",
      },
      lualine_c = { { "filename", path = 4 } },
      lualine_x = {
        {
          require("noice").api.statusline.mode.get,
          cond = require("noice").api.statusline.mode.has,
          color = { fg = "#DC8A78" },
        },
        "copilot",
        "filetype",
      },
      lualine_y = { "searchcount" },
      lualine_z = {
        "selectioncount",
        -- {
        --   require("arrow.statusline").text_for_statusline_with_icons,
        --   cond = require("arrow.statusline").is_on_arrow_file,
        -- },
        "location",
        "progress",
      },
    },
    extensions = { "quickfix", "man", "fugitive" },
  }
end

return M
