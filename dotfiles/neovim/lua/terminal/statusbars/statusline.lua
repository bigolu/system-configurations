-- vim:foldmethod=marker

-- statusline helpers {{{
local function collect_to_list(acc, _index, item)
  table.insert(acc, item)
  return acc
end

local function make_statusline(...)
  local right_border = "%#StatusLine# %#StatusLinePowerlineOuter#"
  local right_border_length =
    vim.api.nvim_eval_statusline(right_border, {}).width

  local left_border = "%#StatusLinePowerlineOuter#"
  local left_border_length = vim.api.nvim_eval_statusline(left_border, {}).width

  local space_remaining = vim.o.columns
    - (left_border_length + right_border_length)

  local item_separator = "  "
  local item_separator_length = #item_separator

  local function has_space(index, item)
    -- I need to remove aligners because they affect the width.
    local length = vim.api.nvim_eval_statusline(item:gsub("%%=", ""), {}).width
    space_remaining = space_remaining - length
    if index > 1 then
      space_remaining = space_remaining - item_separator_length
    end
    return space_remaining >= 0
  end

  -- iter() filters out nil values
  local items =
    vim.iter({ ... }):enumerate():filter(has_space):fold({}, collect_to_list)

  return left_border .. table.concat(items, item_separator) .. right_border
end
-- }}}

local function is_pattern_in_buffer(pattern)
  -- PERF
  if vim.fn.line("$") < 300 then
    return vim.fn.search(pattern, "nw", 0, 50) > 0
  else
    return false
  end
end

local function get_mode_and_left_items()
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
  local mode = "%#status_line_mode# "
    .. (mode_map[vim.api.nvim_get_mode().mode] or "?")

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
    local count = vim.diagnostic.count(nil, { severity = datum.severity })[datum.severity]
      or 0
    if count > 0 then
      table.insert(diagnostic_list, datum.icon .. count)
    end
  end
  local diagnostics = nil
  if #diagnostic_list > 0 then
    diagnostics = table.concat(diagnostic_list, " ")
  end

  local mixed_indentation_indicator = nil
  -- Taken from here:
  -- https://github.com/vim-airline/vim-airline/blob/3b9e149e19ed58dee66e4842626751e329e1bd96/autoload/airline/extensions/whitespace.vim#L30
  if is_pattern_in_buffer([[\v(^\t+ +)|(^ +\t+)]]) then
    mixed_indentation_indicator = "%#StatusLineErrorText#[  mixed indent]"
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
    reg_recording = "%#StatusLineRecordingIndicator# %#StatusLineNormal#REC@"
      .. recording_register
  end

  -- iter() filters out nil values
  local items = vim
    .iter({
      readonly,
      diagnostics,
      mixed_indentation_indicator,
      mixed_line_endings,
      reg_recording,
    })
    :totable()
  local items_joined = (
    #items > 0
      and " %#StatusLinePowerlineInner#%#StatusLinePowerlineOuter#"
    or ""
  )
    .. table.concat(items, "%#StatusLineSeparator#" .. "  ")
    .. (#items > 0 and "%#StatusLinePowerlineInner#" or " ")

  return mode .. items_joined
end

function StatusLine()
  local showcmd = "%#StatusLineShowcmd#%S"
  local aligner = "%#StatusLineFill#%="
  local statusline_separator = aligner .. showcmd .. aligner

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
    get_mode_and_left_items(),
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

vim.o.laststatus = 3
vim.o.statusline = "%!v:lua.StatusLine()"
