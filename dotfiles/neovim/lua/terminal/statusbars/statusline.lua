-- vim:foldmethod=marker

vim.o.laststatus = 3
vim.o.statusline = "%!v:lua.StatusLine()"

-- statusline helpers {{{
local function get_mode_indicator()
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
  local mode = mode_map[vim.api.nvim_get_mode().mode]
  if mode == nil then
    mode = "?"
  end

  return "%#StatusLinePowerlineOuter#" .. "%#status_line_mode# " .. mode
end

local function collect_to_list(acc, _index, item)
  table.insert(acc, item)
  return acc
end

local function make_statusline(left_items, right_items)
  local mode_indicator = get_mode_indicator()
  local mode_indicator_length =
    vim.api.nvim_eval_statusline(mode_indicator, {}).width

  local item_separator = "  "
  local item_separator_length = #item_separator

  local showcmd = "%#StatusLineShowcmd#%S"
  local statusline_separator = "%#StatusLineFill# %="
    .. showcmd
    .. "%#StatusLineFill#%= "
  -- I need to remove the aligners from the statusline separator because they affect
  -- the width.
  local statusline_separator_length =
    vim.api.nvim_eval_statusline(statusline_separator:gsub("%%=", ""), {}).width

  local right_side_padding = "%#StatusLine# %#StatusLinePowerlineOuter#"
  local right_side_padding_length =
    vim.api.nvim_eval_statusline(right_side_padding, {}).width

  local space_remaining = vim.o.columns
    - (
      mode_indicator_length
      + statusline_separator_length
      + right_side_padding_length
    )
  local function has_space(index, item)
    local length = vim.api.nvim_eval_statusline(item, {}).width
    space_remaining = space_remaining - length
    if index > 1 then
      space_remaining = space_remaining - item_separator_length
    end
    return space_remaining >= 0
  end
  local function filter_items(items)
    return vim
      -- iter() filters out nil values
      .iter(items)
      :enumerate()
      :filter(has_space)
      :fold({}, collect_to_list)
  end

  left_items = filter_items(left_items)
  -- TODO: I'm not accounting for the length of these strings in space_remaining
  local left_side = mode_indicator
    .. (#left_items > 0 and " %#StatusLinePowerlineInner#%#StatusLinePowerlineOuter#" or "")
    .. table.concat(left_items, "%#StatusLineSeparator#" .. item_separator)
    .. (#left_items > 0 and "%#StatusLinePowerlineInner#" or " ")

  right_items = filter_items(right_items)
  local right_side = table.concat(right_items, item_separator)
    .. right_side_padding

  return left_side .. statusline_separator .. right_side
end

local function is_pattern_in_buffer(pattern)
  -- PERF
  if vim.fn.line("$") < 300 then
    return vim.fn.search(pattern, "nw", 0, 50) > 0
  else
    return false
  end
end
-- }}}

function StatusLine()
  local basename = "%t"

  local position = "%#StatusLine#" .. "%03l:%03c"

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

  local filetype = nil
  if string.len(vim.o.filetype) > 0 then
    filetype = "%#StatusLine#" .. vim.o.filetype
  end

  local readonly = nil
  if vim.o.readonly then
    local indicator = "󰍁 "
    readonly = "%#StatusLineStandoutText#" .. indicator
  end

  local reg_recording = nil
  local recording_register = vim.fn.reg_recording()
  if recording_register ~= "" then
    reg_recording = "%#StatusLineRecordingIndicator# %#StatusLineNormal#REC@"
      .. recording_register
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

  local maximized = nil
  if IsMaximized then
    local indicator = " "
    maximized = "%#StatusLine#" .. indicator
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

  return make_statusline({
    readonly,
    diagnostics,
    mixed_indentation_indicator,
    mixed_line_endings,
    reg_recording,
  }, {
    maximized,
    lsp_info,
    filetype,
    fileformat,
    fileencoding,
    position,
    basename,
  })
end
