local function make_statusline(...)
  local right_border = " "
  local right_border_length = vim.api.nvim_eval_statusline(right_border, {}).width

  local left_border = " "
  local left_border_length = vim.api.nvim_eval_statusline(left_border, {}).width

  local space_remaining = vim.o.columns - (left_border_length + right_border_length)

  local item_separator = "  "
  local item_separator_length = #item_separator

  local function has_space(index, item)
    -- Remove aligners so they don't affect the width
    local length = vim.api.nvim_eval_statusline(item:gsub("%%=", ""), {}).width
    space_remaining = space_remaining - length
    if index > 1 then
      space_remaining = space_remaining - item_separator_length
    end
    return space_remaining >= 0
  end

  -- iter() filters out nil values
  local joined_items = vim
    .iter({ ... })
    :enumerate()
    :filter(has_space)
    :map(function(_index, item)
      return item
    end)
    :join(item_separator)

  return left_border .. joined_items .. right_border
end

local function is_current_buffer_too_big_to_search()
  local max_filesize = 100 * 1024 -- 100 KB
  -- I make sure to use something that gets the size of the buffer and not file
  -- because I may be editing a file that isn't stored locally e.g. `nvim <url>`
  return vim.fn.wordcount().bytes > max_filesize
end

local function is_pattern_in_buffer(pattern)
  if is_current_buffer_too_big_to_search() then
    return false
  else
    return vim.fn.search(pattern, "nw", 0, 50) > 0
  end
end

function StatusLine()
  local normal = "NORMAL"
  local operator_pending = "OPERATOR-PENDING"
  local visual = "VISUAL"
  local visual_line = visual .. "-LINE"
  local visual_block = visual .. "-BLOCK"
  local visual_replace = visual .. "-REPLACE"
  local select = "SELECT"
  local select_line = select .. "-LINE"
  local select_block = select .. "-BLOCK"
  local insert = "INSERT"
  local replace = "REPLACE"
  local command = "COMMAND"
  local ex = "EX"
  local more = "MORE"
  local confirm = "CONFIRM"
  local shell = "SHELL"
  local terminal = "TERMINAL"
  local mode_map = {
    ["n"] = normal,
    ["no"] = operator_pending,
    ["nov"] = operator_pending,
    ["noV"] = operator_pending,
    ["no\22"] = operator_pending,
    ["niI"] = normal,
    ["niR"] = normal,
    ["niV"] = normal,
    ["nt"] = normal,
    ["ntT"] = normal,
    ["v"] = visual,
    ["vs"] = visual,
    ["V"] = visual_line,
    ["Vs"] = visual_line,
    ["\22"] = visual_block,
    ["\22s"] = visual_block,
    ["s"] = select,
    ["S"] = select_line,
    ["\19"] = select_block,
    ["i"] = insert,
    ["ic"] = insert,
    ["ix"] = insert,
    ["R"] = replace,
    ["Rc"] = replace,
    ["Rx"] = replace,
    ["Rv"] = visual_replace,
    ["Rvc"] = visual_replace,
    ["Rvx"] = visual_replace,
    ["c"] = command,
    ["cv"] = ex,
    ["ce"] = ex,
    ["r"] = replace,
    ["rm"] = more,
    ["r?"] = confirm,
    ["!"] = shell,
    ["t"] = terminal,
  }
  local mode = "%#StatusLineMode#" .. mode_map[vim.api.nvim_get_mode().mode]

  local readonly = nil
  if vim.o.readonly then
    local indicator = "󰍁 "
    readonly = "%#StatusLineStandoutText#" .. indicator
  end

  local diagnostic_data = {
    {
      severity = vim.diagnostic.severity.HINT,
      icon = "%#StatusLineHintText# ",
    },
    {
      severity = vim.diagnostic.severity.INFO,
      icon = "%#StatusLineInfoText# ",
    },
    {
      severity = vim.diagnostic.severity.WARN,
      icon = "%#StatusLineWarningText# ",
    },
    {
      severity = vim.diagnostic.severity.ERROR,
      icon = "%#StatusLineErrorText# ",
    },
  }
  local diagnostic_list = {}
  for _, datum in ipairs(diagnostic_data) do
    local count = vim.diagnostic.count(0, { severity = datum.severity })[datum.severity] or 0
    if count > 0 then
      table.insert(diagnostic_list, datum.icon .. count)
    end
  end
  local diagnostics = nil
  if #diagnostic_list > 0 then
    diagnostics = table.concat(diagnostic_list, " ")
  end

  local mixed_indentation = nil
  -- Taken from here:
  -- https://github.com/vim-airline/vim-airline/blob/3b9e149e19ed58dee66e4842626751e329e1bd96/autoload/airline/extensions/whitespace.vim#L30
  if is_pattern_in_buffer([[\v(^\t+ +)|(^ +\t+)]]) then
    mixed_indentation = "%#StatusLineErrorText#[  mixed indent]"
  end

  local mixed_line_endings = nil
  local line_ending_types_found = 0
  if is_pattern_in_buffer([[\v\n]]) then
    line_ending_types_found = line_ending_types_found + 1
  end
  if is_pattern_in_buffer([[\v\r]]) then
    line_ending_types_found = line_ending_types_found + 1
  end
  if is_pattern_in_buffer([[\v\r\n]]) then
    line_ending_types_found = line_ending_types_found + 1
  end
  if line_ending_types_found > 1 then
    mixed_line_endings = "%#StatusLineErrorText#[ mixed line-endings]"
  end

  local reg_recording = nil
  local recording_register = vim.fn.reg_recording()
  if recording_register ~= "" then
    reg_recording = "%#StatusLineRecordingIndicator# %#StatusLineNormal#REC@" .. recording_register
  end

  local showcmd = "%S"
  local aligner = "%="
  local statusline_separator = "%#StatusLine#" .. aligner .. showcmd .. aligner

  local maximized = nil
  if IsMaximized then
    maximized = "%#StatusLine# "
  end

  local lsp_info = nil
  local language_server_count_for_current_buffer =
    -- TODO: A definition of get_clients in mini.nvim is being used by linters
    -- instead of the one from the neovim runtime. Since it has a different signature
    -- than the real one, linters think I'm calling it incorrectly.
    ---@diagnostic disable-next-line: redundant-parameter
    #vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })
  if language_server_count_for_current_buffer > 0 then
    lsp_info = "%#StatusLine# " .. language_server_count_for_current_buffer
  end

  local filetype = nil
  if string.len(vim.o.filetype) > 0 then
    filetype = "%#StatusLine#" .. vim.o.filetype
  end

  local fileformat = nil
  if vim.o.fileformat == "mac" then
    fileformat = " CR"
  elseif vim.o.fileformat == "dos" then
    fileformat = " CRLF"
  end
  if fileformat ~= nil then
    fileformat = "%#StatusLine#" .. fileformat
  end

  local fileencoding = nil
  if #vim.o.fileencoding > 0 and vim.o.fileencoding ~= "utf-8" then
    fileencoding = "%#StatusLine#" .. string.upper(vim.o.fileencoding)
  end

  local position = "%#StatusLine#" .. "%l:%c"

  local basename = "%t"

  return make_statusline(
    mode,
    readonly,
    diagnostics,
    mixed_indentation,
    mixed_line_endings,
    reg_recording,
    statusline_separator,
    maximized,
    position,
    filetype,
    fileformat,
    fileencoding,
    lsp_info,
    basename
  )
end

local function is_virtual_line()
  return vim.v.virtnum < 0
end

local function is_wrapped_line()
  return vim.v.virtnum > 0
end

-- Fold column calculation was taken from the following files in the plugin
-- statuscol.nvim:
-- https://github.com/luukvbaal/statuscol.nvim/blob/98d02fc90ebd7c4674ec935074d1d09443d49318/lua/statuscol/ffidef.lua
-- https://github.com/luukvbaal/statuscol.nvim/blob/98d02fc90ebd7c4674ec935074d1d09443d49318/lua/statuscol/builtin.lua
local ffi = require("ffi")
-- I moved this call to `cdef` outside the fold function because I was getting
-- the error "table overflow" a few seconds into using neovim. Plus, not calling
-- this during the fold function is faster.
ffi.cdef([[
  int next_namespace_id;
  uint64_t display_tick;
  typedef struct {} Error;
  typedef struct {} win_T;
  typedef struct {
    int start;  // line number where deepest fold starts
    int level;  // fold level, when zero other fields are N/A
    int llevel; // lowest level that starts in v:lnum
    int lines;  // number of lines from v:lnum to end of closed fold
  } foldinfo_T;
  foldinfo_T fold_info(win_T* wp, int lnum);
  win_T *find_window_by_handle(int Window, Error *err);
  int compute_foldcolumn(win_T *wp, int col);
  int win_col_off(win_T *wp);
]])
-- This should be much simpler when this issue is resolved:
-- https://github.com/neovim/neovim/issues/21740
local function get_fold_sign()
  local wp = ffi.C.find_window_by_handle(vim.g.statusline_winid, ffi.new("Error"))
  local foldinfo = ffi.C.fold_info(wp, vim.v.lnum)
  local string = "%#FoldColumn#"
  local level = foldinfo.level

  if is_virtual_line() or is_wrapped_line() or level == 0 then
    return "  "
  end

  if foldinfo.start == vim.v.lnum then
    local closed = foldinfo.lines > 0
    if closed then
      string = string .. ""
    else
      string = string .. ""
    end
  else
    string = string .. " "
  end
  string = string .. " "

  return string
end

function StatusColumn()
  local line_number_width = math.ceil(math.log(vim.fn.line("$", vim.g.statusline_winid), 10))
  local line_number_min_width = line_number_width + 1
  local line_number = "%-" .. line_number_min_width .. "l"

  local git = "%s"
  local fold = get_fold_sign()
  local margin = "%#Normal# "

  return git .. line_number .. fold .. margin
end

vim.o.laststatus = 3
vim.o.statusline = "%!v:lua.StatusLine()"

vim.o.statuscolumn = "%!v:lua.StatusColumn()"
vim.o.signcolumn = "yes:1"
