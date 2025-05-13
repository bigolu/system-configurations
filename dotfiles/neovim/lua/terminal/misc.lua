-- vim:foldmethod=marker

-- Windows {{{
-- open new horizontal and vertical panes to the right and bottom respectively
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.winminheight = 0
vim.o.winminwidth = 0
vim.keymap.set("n", "<C-\\>", vim.cmd.vsplit)
vim.keymap.set("n", "<C-->", vim.cmd.split)
vim.keymap.set("n", "<C-_>", "<C-->", { expr = true })
vim.keymap.set("n", "<C-[>", vim.cmd.tabprevious)
vim.keymap.set("n", "<C-]>", vim.cmd.tabnext)
-- }}}

-- Settings {{{
vim.o.mouse = "a"
vim.o.jumpoptions = "stack"
vim.o.mousemoveevent = true
vim.o.concealcursor = "nc"

-- center the current line
vim.o.scrolloff = 100

-- Gets rid of the press enter prompt when accessing a file over a network
vim.g.netrw_silent = 1

-- persist undo history to disk
vim.o.undofile = true

-- Plugins expect this to be POSIX compliant and my $SHELL is fish.
vim.o.shell = "sh"

vim.o.ttimeout = true
vim.o.ttimeoutlen = 50

vim.o.scroll = 1
vim.o.smoothscroll = true

vim.o.shortmess = "ltToOFs"
-- }}}

-- Mappings {{{
vim.keymap.set("", "<C-s>", vim.cmd.wall)

local function c_x(buffer)
  vim.keymap.set("", "<C-x>", function()
    vim.cmd([[
      confirm xall
    ]])
  end, {
    buffer = buffer,
  })
end
c_x()
vim.api.nvim_create_autocmd("FileType", {
  pattern = "gitrebase",
  callback = function()
    c_x(true)
  end,
})

-- suspend vim
vim.keymap.set({ "n", "i", "x" }, "<C-z>", "<Cmd>suspend<CR>", {
  desc = "Suspend [background]",
})

-- To have separate mappings for <Tab> and <C-i> you have to map both. Since I
-- want the default behavior for <C-i> I just map it to itself. Source:
-- https://neovim.io/doc/user/motion.html#jump-motions
vim.keymap.set({ "n" }, "<C-i>", "<C-i>")

vim.keymap.set("n", [[\ ]], function()
  vim.o.list = not vim.o.list
end, { silent = true, desc = "Toggle whitespace indicator" })
vim.keymap.set("n", [[\n]], function()
  vim.o.number = not vim.o.number
end, { silent = true, desc = "Toggle line numbers" })

vim.keymap.set("n", "<C-q>", function()
  vim.cmd([[
    silent wall
  ]])

  local tab_count = vim.fn.tabpagenr("$")

  local function is_not_float(window)
    return vim.api.nvim_win_get_config(window).relative == ""
  end
  local window_count = #vim.tbl_filter(is_not_float, vim.api.nvim_list_wins())

  -- If this is the last tab and window, exit vim
  local is_last_window = window_count == 1
  if tab_count == 1 and is_last_window then
    local is_linked_to_file = #vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()) > 0
    -- Only `confirm` if the buffer is linked to a file
    if is_linked_to_file then
      vim.cmd([[
        confirm qall
      ]])
    else
      -- add '!' to ignore unsaved changes
      vim.cmd([[
        qall!
      ]])
    end
    return
  end

  vim.cmd.close()
end, { silent = true, desc = "Close pane [split,window]" })
-- }}}

-- Autosave {{{
-- Emulates the behavior of VS Code's autosave "onFocusChange"
vim.api.nvim_create_autocmd({ "FocusLost", "VimSuspend", "BufLeave" }, {
  callback = function(_)
    vim.cmd([[
      silent wall
    ]])
  end,
})
-- }}}

-- Indentation {{{
vim.o.expandtab = true
vim.o.autoindent = true
vim.o.smarttab = true
-- Round indent to multiple of shiftwidth (applies to < and >)
vim.o.shiftround = true
local tab_width = 2
vim.o.tabstop = tab_width
vim.o.shiftwidth = tab_width
vim.o.softtabstop = tab_width
-- }}}

-- Command line {{{
-- on first wildchar press (<Tab>), show all matches and complete the longest common substring among
-- on them. subsequent wildchar presses, cycle through matches
vim.o.wildmode = "longest:full,full"
vim.o.wildoptions = "pum,fuzzy"
vim.o.cmdheight = 0
vim.o.showcmdloc = "statusline"

vim.keymap.set("c", "<C-a>", "<C-b>", { remap = true })
vim.keymap.set({ "ca" }, "lua", function()
  if vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == "lua" then
    return "lua="
  else
    return "lua"
  end
end, { expr = true })
vim.keymap.set({ "ca" }, "h", function()
  if vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == "h" then
    return "tab help"
  else
    return "h"
  end
end, { expr = true })

vim.api.nvim_create_autocmd("CmdlineEnter", {
  pattern = [=[[/\?]]=],
  callback = function()
    vim.o.hlsearch = true
  end,
})
vim.api.nvim_create_autocmd("CmdlineLeave", {
  pattern = [=[[/\?]]=],
  callback = function()
    vim.o.hlsearch = false
  end,
})
-- }}}

-- Terminal {{{
vim.keymap.set("t", "jk", [[<C-\><C-n>]])

vim.api.nvim_create_autocmd("TermOpen", {
  callback = function(_)
    vim.cmd.startinsert()
  end,
})
-- }}}

-- Breakopt {{{
vim.o.breakindent = true
vim.o.showbreak = "↳"
-- }}}
