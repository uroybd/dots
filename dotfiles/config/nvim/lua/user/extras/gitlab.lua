local M = {
  "harrisoncramer/gitlab.nvim",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim",
    "sindrets/diffview.nvim",
    "stevearc/dressing.nvim", -- Recommended but not required. Better UI for pickers.
    "nvim-tree/nvim-web-devicons", -- Recommended but not required. Icons in discussion tree.
  },
}

function M.build()
  require("gitlab.server").build(true)
end

function M.config()
  local gitlab = require "gitlab"
  gitlab.setup()
  local gitlab_server = require "gitlab.server"
  local wk = require "which-key"

  -- wk.register({
  --   ["<leader>glc"] = { gitlab.create_multiline_comment, "Create Multiline Comment" },
  --   ["<leader>glC"] = { gitlab.create_comment_suggestion, "Create Comment Suggestion" },
  -- }, {
  --   mode = "v",
  -- })

  wk.add {
    { "<leader>gl", group = "Gitlab" },
    { "<leader>glb", gitlab.choose_merge_request, desc = "Choose Merge Request" },
    { "<leader>glr", gitlab.review, desc = "Review" },
    { "<leader>gls", gitlab.summary, desc = "Summary" },
    { "<leader>glA", gitlab.approve, desc = "Approve" },
    { "<leader>glx", gitlab.revoke, desc = "Revoke" },
    { "<leader>glc", gitlab.create_comment, desc = "Create Comment" },
    { "<leader>glO", gitlab.create_mr, desc = "Create Merge Request" },
    { "<leader>glm", gitlab.move_to_discussion_tree_from_diagnostic, desc = "Move to Discussion Tree" },
    { "<leader>gln", gitlab.create_note, desc = "Create Note" },
    { "<leader>gld", gitlab.toggle_discussions, desc = "Toggle Discussions" },
    { "<leader>gla", group = "Assignee" },
    { "<leader>glaa", gitlab.add_assignee, desc = "Add Assignee" },
    { "<leader>glad", gitlab.delete_assignee, desc = "Delete Assignee" },
    { "<leader>glL", group = "Label" },
    { "<leader>glla", gitlab.add_label, desc = "Add Label" },
    { "<leader>glld", gitlab.delete_label, desc = "Delete Label" },
    { "<leader>glR", group = "Reviewer" },
    { "<leader>glRa", gitlab.add_reviewer, desc = "Add Reviewer" },
    { "<leader>glRd", gitlab.delete_reviewer, desc = "Delete Reviewer" },
    { "<leader>glp", gitlab.pipeline, desc = "Pipeline" },
    { "<leader>glo", gitlab.open_in_browser, desc = "Open in Browser" },
    { "<leader>glM", gitlab.merge, desc = "Merge" },
    { "<leader>glu", gitlab.copy_mr_url, desc = "Copy Merge Request URL" },
    { "<leader>glP", gitlab.publish_all_drafts, desc = "Publish All Drafts" },
    { "<leader>glD", gitlab.toggle_draft_mode, desc = "Toggle Draft Mode" },
    { "<leader>glq", gitlab_server.restart, desc = "Restart" },
  }
end

return M
