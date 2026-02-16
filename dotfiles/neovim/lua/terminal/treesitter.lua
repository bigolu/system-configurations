local function is_current_buffer_too_big_to_highlight()
  local max_filesize = 100 * 1024 -- 100 KB
  -- I make sure to use something that gets the size of the buffer and not file
  -- because I may be editing a file that isn't stored locally e.g. `nvim <url>`
  return vim.fn.wordcount().bytes > max_filesize
end

local filetypes_with_regex_highlights = vim.fn.getcompletion("", "syntax") or {}

local filetypes_with_treesitter_parser = require("nvim-treesitter.parsers")

local function fix(filetype)
  return ({
    gitrebase = "git_rebase",
  })[filetype] or filetype
end

vim.cmd.syntax("manual")
vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    if not is_current_buffer_too_big_to_highlight() then
      if filetypes_with_treesitter_parser[fix(vim.bo.filetype)] ~= nil then
        vim.treesitter.start()
      elseif vim.tbl_contains(filetypes_with_regex_highlights, vim.bo.filetype) then
        vim.bo.syntax = "ON"
      end
    end
  end,
})

require("treesitter-context").setup({
  line_numbers = false,
  multiline_threshold = 1,
})
vim.keymap.set({ "n", "x" }, "[s", function()
  require("treesitter-context").go_to_context(vim.v.count1)
end, { silent = true })
vim.keymap.set("n", [[\s]], function()
  vim.cmd.TSContext("toggle")
end)
