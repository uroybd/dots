local M = {
      'javiorfo/nvim-ship',
      lazy = true,
      ft = 'ship',
      cmd = { "ShipCreate", "ShipCreateEnv" },
      dependencies = {
             'javiorfo/nvim-spinetta',
           'javiorfo/nvim-popcorn',
           'hrsh7th/nvim-cmp' -- nvim-cmp is optional
        },
      opts = {
            -- Not necessary. Only if you want to change the setup.
            -- The following are the default values
            view = {
              autocomplete = true
            },
          request = {
              timeout = 30, 
              autosave = true,
              insecure = false  
              },
          response = {
              show_headers = 'all',
              window_type = 'h',
              -- border_type = require'popcorn.borders'.double_border, -- Only applied for 'p' window_type
              size = 20,
              redraw = true
              },
          output = {
              save = true,
              override = true,
              folder = "output",
          },
          internal = {
              log_debug = false,
          }
   }
}

return M
