-- vim:foldmethod=marker

local fidget = require("fidget")
fidget.setup({
  progress = {
    ignore_done_already = true,
    suppress_on_insert = true,
    ignore = { "null-ls" },
    display = {
      render_limit = 1,
      done_ttl = 0.1,
      done_icon = "󰄬",
      done_style = "FidgetNormal",
      progress_style = "FidgetAccent",
      group_style = "FidgetAccent",
      icon_style = "FidgetIcon",
      progress_icon = { "dots" },
    },
  },
  notification = {
    view = {
      group_separator = "─────",
    },
    window = {
      normal_hl = "FidgetNormal",
      winblend = 0,
      zindex = 1,
      max_width = 40,
    },
  },
})
vim.notify = fidget.notify

local mc = require("multicursor-nvim")
mc.setup()
vim.keymap.set("n", "<M-leftmouse>", mc.handleMouse)
vim.keymap.set({ "n", "v" }, "<c-c>", mc.toggleCursor)
vim.keymap.set("n", "<esc>", function()
  if not mc.cursorsEnabled() then
    mc.enableCursors()
  elseif mc.hasCursors() then
    mc.clearCursors()
  end
end)

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
local function c_x(buffer)
  vim.keymap.set("", "<C-x>", function()
    vim.cmd([[
      confirm qall
    ]])
  end, {
    desc = "Quit [exit,close]",
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
--
-- TODO: These issues may affect how I want to do this:
-- https://github.com/neovim/neovim/pull/20801
-- https://github.com/neovim/neovim/issues/1380
-- https://github.com/neovim/neovim/issues/12605
--
-- TODO: When I call checktime after pressing something like 'cin' in normal mode, I get
-- E565 which doesn't make sense since I don't think complete mode was active, mini.ai was
-- just prompting me for a char. In any case, I tried checking if completion mode was active
-- first, but it wasn't so I still got this error. So now I'm just using pcall which isn't ideal
-- since it will suppress other errors too.
local function checktime()
  return pcall(vim.cmd.checktime)
end
---@diagnostic disable-next-line: undefined-field
local timer = vim.uv.new_timer()
timer:start(
  0,
  500,
  vim.schedule_wrap(function()
    -- you can't run checktime in the commandline
    if vim.fn.getcmdwintype() ~= "" then
      return
    end

    -- check for changes made outside of vim
    local success = checktime()
    if not success then
      return
    end

    -- Give buffers a chance to update via 'autoread' in response to the checktime done above by
    -- deferring.
    vim.defer_fn(function()
      -- I'm saving this way instead of :wall because I want to filter out buffers with buftype
      -- 'acwrite' because overseer.nvim uses that for floats that require user input and my
      -- autosave was causing them to automatically close.
      vim
        .iter(vim.api.nvim_list_bufs())
        :filter(function(buf)
          -- TODO: Considering also checking filereadable, but not sure if that would cause
          -- excessive disk reads
          return vim.api.nvim_buf_is_loaded(buf)
            and not vim.bo[buf].readonly
            and vim.bo[buf].modified
            and (vim.bo[buf].buftype == "")
            and (#vim.api.nvim_buf_get_name(buf) > 0)
        end)
        :each(function(buf)
          vim.api.nvim_buf_call(buf, function()
            ---@diagnostic disable-next-line: param-type-mismatch
            local was_successful = pcall(vim.cmd, "silent write")
            if not was_successful then
              vim.notify(string.format("Failed to write buffer #%s, disabling autosave...", buf), vim.log.levels.ERROR)
              timer:stop()
            end
          end)
        end)
    end, 300)
  end)
)
-- Check for changes made outside of vim. Source:
-- https://unix.stackexchange.com/questions/149209/refresh-changed-content-of-file-opened-in-vim/383044#383044
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI", "VimResume" }, {
  callback = function()
    -- you can't run checktime in the commandline
    if vim.fn.getcmdwintype() ~= "" then
      return
    end
    checktime()
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
