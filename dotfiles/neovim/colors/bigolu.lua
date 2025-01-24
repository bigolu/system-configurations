-- stylua: ignore start

vim.g.colors_name = "bigolu"

local colors = nil
if vim.o.background == "dark" then
  colors = {
    [0] = "#1d2129",
    [1] = "#BF616A",
    [2] = "#A3BE8C",
    [3] = "#EBCB8B",
    [4] = "#81A1C1",
    [5] = "#B48EAD",
    [6] = "#88C0D0",
    [7] = "#D8DEE9",
    [8] = "#78849b",
    [9] = "#BF616A",
    [10] = "#A3BE8C",
    [11] = "#d08770",
    [12] = "#81A1C1",
    [13] = "#B48EAD",
    [14] = "#8FBCBB",
    [15] = "#78849b",
    bg2 = "#2f333e",
    pmenu = "#242833",
    pmenu_thumb = "#3a3e49",
    error_bg = "#2e2129",
    warn_bg = "#2a2e29",
    info_bg = "#1c2935",
    ok_bg = "#1e2915",
    inlay_bg = "#292d38",
    inlay_fg = "#abb4c4",
    string = "#8FBCBB",
    bracket = "#88C0D0",
  }
else
  colors = {
    [0] = "#ffffff",
    [1] = "#cf222e",
    [2] = "#116329",
    [3] = "#d67427",
    [4] = "#0969da",
    [5] = "#652d90",
    [6] = "#005C8A",
    [7] = "#1f2328",
    [8] = "#808080",
    [9] = "#a40e26",
    [10] = "#1a7f37",
    [11] = "#c96765",
    [12] = "#218bff",
    [13] = "#652d90",
    [14] = "#005C8A",
    [15] = "#808080",
    bg2 = "#e3e5e7",
    pmenu = "#eef0f2",
    pmenu_thumb = "#d1d3d5",
    error_bg = "#fceff0",
    warn_bg = "#fdf7f1",
    info_bg = "#edf4fe",
    ok_bg = "#e8fbee",
    inlay_bg = "#292d38",
    inlay_fg = "#abb4c4",
    string = "#a40e26",
    bracket = "#652d90",
  }
end

local groups = {
  -- modes {{{
  -- I'm intentionally not using "NONE" for bg, if I'm using true colors for the
  -- foreground I should use them for the background too to ensure good contrast.
  Normal = { ctermbg = "NONE", ctermfg = 7, bg = colors[0], fg = colors[7] },
  Visual = { ctermfg = 3, reverse = true, fg = colors[3] },
  -- }}}

  -- searching {{{
  Search = "Visual", -- Last search pattern highlighting (see 'hlsearch'). Also used for similar items that need to stand out.
  CurSearch = "Search", -- Highlighting a search pattern under the cursor (see 'hlsearch')
  IncSearch = "Search", -- 'incsearch' highlighting; also used for the text replaced with ":s///c"
  -- }}}

  -- diagnostics {{{
  ErrorMsg = { ctermfg = 1, fg = colors[1] }, -- Error messages on the command line
  WarningMsg = { ctermfg = 3, fg = colors[3] }, -- Warning messages
  Error = { undercurl = true, ctermfg = 1, sp = colors[1] }, -- Any erroneous construct
  Warning = { undercurl = true, ctermfg = 3, sp = colors[3] },
  NvimInternalError = "ErrorMsg",
  DiagnosticError = "ErrorMsg", -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
  DiagnosticWarn = "WarningMsg", -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
  DiagnosticInfo = { ctermfg = 4, fg = colors[4] }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
  DiagnosticHint = "DiagnosticInfo", -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
  DiagnosticOk = { ctermfg = 2, fg = colors[2] }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
  DiagnosticVirtualTextError = { ctermfg = 1, bold = true, bg = colors.error_bg, fg = colors[1] }, -- Used for "Error" diagnostic virtual text.
  DiagnosticVirtualTextWarn = { ctermfg = 3, bold = true, bg = colors.warn_bg, fg = colors[3] }, -- Used for "Warn" diagnostic virtual text.
  DiagnosticVirtualTextInfo = { ctermfg = 4, bold = true, bg = colors.info_bg, fg = colors[4] }, -- Used for "Info" diagnostic virtual text.
  DiagnosticVirtualTextHint = "DiagnosticVirtualTextInfo", -- Used for "Hint" diagnostic virtual text.
  DiagnosticVirtualTextOk = { ctermfg = 2, bold = true, bg = colors.ok_bg, fg = colors[2] }, -- Used for "Ok" diagnostic virtual text.
  DiagnosticUnderlineError = "Error", -- Used to underline "Error" diagnostics.
  DiagnosticUnderlineWarn = "Warning", -- Used to underline "Warn" diagnostics.
  DiagnosticUnderlineInfo = { ctermfg = 4, undercurl = true, sp = colors[4] }, -- Used to underline "Info" diagnostics.
  DiagnosticUnderlineHint = "DiagnosticUnderlineInfo", -- Used to underline "Hint" diagnostics.
  DiagnosticUnderlineOk = { ctermfg = 2, undercurl = true, sp = colors[2] }, -- Used to underline "Ok" diagnostics.
  DiagnosticFloatingError = "DiagnosticError", -- Used to color "Error" diagnostic messages in diagnostics float. See |vim.diagnostic.open_float()|
  DiagnosticFloatingWarn = "DiagnosticWarn", -- Used to color "Warn" diagnostic messages in diagnostics float.
  DiagnosticFloatingInfo = "DiagnosticInfo", -- Used to color "Info" diagnostic messages in diagnostics float.
  DiagnosticFloatingHint = "DiagnosticHint", -- Used to color "Hint" diagnostic messages in diagnostics float.
  DiagnosticFloatingOk = "DiagnosticOk", -- Used to color "Ok" diagnostic messages in diagnostics float.
  DiagnosticUnnecessary = { ctermfg = 8, undercurl = true, sp = colors[8] },
  DiagnosticDeprecated = "DiagnosticUnnecessary",
  -- }}}

  -- float {{{
  FloatBorder = { ctermfg = 8, fg = colors[8] }, -- Border of floating windows.
  FloatTitle = { ctermfg = 14, fg = colors.string, bold = true }, -- Title of floating windows.
  -- }}}

  -- syntax groups {{{
  Comment = { ctermfg = 8, fg = colors[8] }, -- Any comment

  Conditional = { bold = true }, --   if, then, else, endif, switch, etc.
  Repeat = "Conditional", --   for, do, while, etc.
  Label = "Conditional", --   case, default, etc.
  Keyword = "Conditional", --   any other keyword
  Exception = "Conditional", --   try, catch, throw

  String = { ctermfg = 14, fg = colors.string }, --   A string constant: "this is a string"
  Character = "String", --   A character constant: 'c', '\n'
  -- }}}

  -- diffs {{{
  DiffAdd = { ctermfg = 2, reverse = true, fg = colors[2] }, -- Diff mode: Added line |diff.txt|
  DiffChange = { ctermfg = 3, reverse = true, fg = colors[3] }, -- Diff mode: Changed line |diff.txt|
  DiffDelete = { ctermfg = 1, reverse = true, fg = colors[1] }, -- Diff mode: Deleted line |diff.txt|
  DiffText = { ctermfg = 15, reverse = true, fg = colors[15] }, -- Diff mode: Changed text within a changed line |diff.txt|
  diffAdded = "DiffAdd",
  diffRemoved = "DiffDelete",
  diffChanged = "DiffChange",
  -- }}}

  -- line numbers {{{
  LineNr = { ctermfg = 8, fg = colors[8] }, -- Line number for ":number" and ":#" commands, and when 'number' or 'relativenumber' option is set.
  LineNrAbove = "LineNr", -- Line number for when the 'relativenumber' option is set, above the cursor line
  LineNrBelow = "LineNrAbove", -- Line number for when the 'relativenumber' option is set, below the cursor line
  -- }}}

  -- cursorline {{{
  CursorLine = { underline = true, sp = "fg" }, -- Screen-line at the cursor, when 'cursorline' is set. Low-priority if foreground (ctermfg OR guifg) is not set.
  CursorLineNr = { bold = true }, -- Like LineNr when 'cursorline' or 'relativenumber' is set for the cursor line.
  -- }}}

  -- statusline {{{
  status_line_mode = { ctermfg = 15, reverse = not vim.o.termguicolors, bold = true, bg = colors.bg2 }, -- Status line of current window
  StatusLine = { ctermfg = 15, reverse = not vim.o.termguicolors, bg = colors.bg2, fg = colors[7] }, -- Status line of current window
  StatusLineNormal = { ctermbg = "NONE", ctermfg = 7, nocombine = true, bg = colors[0] },
  StatusLineFill = { ctermbg = 15, ctermfg = 15, bg = colors.bg2, fg = colors.bg2 },
  StatusLineSeparator = { ctermfg = 0, bold = true, bg = colors[0] },
  StatusLineErrorText = { ctermfg = 1, nocombine = true, fg = colors[1], bg = colors[0] },
  StatusLineWarningText = { ctermfg = 3, nocombine = true, fg = colors[3], bg = colors[0] },
  StatusLineStandoutText = "StatusLineWarningText",
  StatusLineInfoText = { ctermfg = 4, nocombine = true, fg = colors[4], bg = colors[0] },
  StatusLineHintText = "StatusLineInfoText",
  StatusLineNC = "StatusLine", -- Status lines of not-current windows. Note: If this is equal to "StatusLine" Vim will use "^^^" in the status line of the current window.
  StatusLineRecordingIndicator = { ctermfg = 1, nocombine = true, fg = colors[1], bg = colors[0] },
  StatusLineShowcmd = "StatusLine",
  StatusLinePowerlineOuter = { ctermfg = 15, nocombine = true, fg = colors.bg2, bg = colors[0] },
  StatusLinePowerlineInner = { ctermfg = 15, nocombine = true, reverse = not vim.o.termguicolors, bg = colors.bg2, fg = colors[0] },
  StatusLineC = { bg = colors.bg2, fg = colors[0] },
  -- }}}

  -- LSP {{{
  LspInfoBorder = "FloatBorder",
  LspInlayHint = { italic = not vim.o.termguicolors, ctermfg = 15, bg = colors.inlay_bg, fg = colors.inlay_fg },
  LspCodeLens = "LspInlayHint", -- Used to color the virtual text of the codelens. See |nvim_buf_set_extmark()|.
  LspCodeLensSeparator = "LspCodeLens", -- Used to color the separator between two or more code lens.
  LspReferenceTarget = { ctermfg = "NONE", ctermbg = "NONE", bg = "NONE", fg = colors[7] },
  -- }}}

  -- pmenu (autocomplete) {{{
  Pmenu = { ctermbg = 15, ctermfg = 0, bg = colors.pmenu, fg = colors[7] }, -- Popup menu: Normal item.
  PmenuSel = { ctermbg = 14, ctermfg = 0, bg = colors.bg2, fg = colors[7] }, -- Popup menu: Selected item.
  PmenuKind = "Pmenu", -- Popup menu: Normal item "kind"
  PmenuKindSel = "PmenuSel", -- Popup menu: Selected item "kind"
  PmenuExtra = "PmenuKind", -- Popup menu: Normal item "extra text"
  PmenuExtraSel = "PmenuKindSel", -- Popup menu: Selected item "extra text"
  PmenuSbar = "Pmenu", -- Popup menu: Scrollbar.
  PmenuThumb = { bg = colors.pmenu_thumb }, -- Popup menu: Thumb of the scrollbar.
  PmenuMatch = { bold = true, fg = colors[6] },
  -- }}}

  -- Tree-Sitter {{{
  ["@comment.documentation"] = "Comment",
  ["@comment.todo"] = {bold = true,},
  ["@comment.error"] = "@comment.todo",
  ["@comment.note"] = "@comment.todo",
  ["@comment.warning"] = "@comment.todo",
  ["@diff.delta"] = "DiffChange",
  ["@diff.minus"] = "DiffDelete",
  ["@diff.plus"] = "DiffAdd",
  ["@keyword.conditional"] = "Keyword",
  ["@keyword.conditional.ternary"] = "Keyword",
  ["@keyword.coroutine"] = "Keyword",
  ["@keyword.debug"] = "Keyword",
  ["@keyword.directive.define"] = "Keyword",
  ["@keyword.exception"] = "Keyword",
  ["@keyword.function"] = "Keyword",
  ["@keyword.import"] = "Keyword",
  ["@keyword.operator"] = "Keyword",
  ["@keyword.repeat"] = "Keyword",
  ["@keyword.return"] = "Keyword",
  ["@keyword.storage"] = "Keyword",
  ["@markup.italic"] = { italic = true },
  ["@markup.link"] = { underline = true, ctermfg = 4, fg = colors[4] },
  ["@markup.link.label"] = "@markup.link",
  ["@markup.link.url"] = "@markup.link",
  ["@markup.strong"] = { bold = true },
  ["@markup.underline"] = "Underlined",
  ["@comment"] = "Comment", -- Comment
  ["@string"] = "String", -- String
  ["@string.documentation"] = "String",
  ["@string.regexp"] = "String",
  ["@string.special.url"] = "Underlined",
  ["@string.special.url.comment"] = { underline = true },
  ["@string.documentation.python"] = "Comment",
  ["@character"] = "Character", -- Character
  ["@label"] = "Label", -- Label
  ["@keyword"] = "Keyword", -- Keyword
  -- }}}

  -- misc. {{{
  Conceal = { ctermfg = 8, fg = colors[8] }, -- Placeholder characters substituted for concealed text (see 'conceallevel')
  Directory = { ctermfg = 4, fg = colors[4] }, -- Directory names (and other special names in listings)
  Folded = { italic = not vim.o.termguicolors, bg = colors.pmenu }, -- Line used for closed folds
  FoldColumn = { ctermfg = 8, fg = colors[8] }, -- 'foldcolumn'
  Substitute = "Search", -- |:substitute| replacement text highlighting
  MsgArea = "StatusLine", -- Area for messages and cmdline
  NonText = { ctermfg = 8, fg = colors[8] }, -- '@' at the end of the window, characters from 'showbreak' and other characters that do not really exist in the text (e.g., ">" displayed when a double-wide character doesn't fit at the end of the line). See also |hl-EndOfBuffer|.
  SpellBad = "Error", -- Word that is not recognized by the spellchecker. |spell| Combined with the highlighting used otherwise.
  SpellCap = "Warning", -- Word that should start with a capital. |spell| Combined with the highlighting used otherwise.
  Whitespace = { ctermfg = 8, fg = colors[8] }, -- "nbsp", "space", "tab" and "trail" in 'listchars'
  WinSeparator = "Whitespace", -- Separator between window splits. Inherits from |hl-VertSplit| by default, which it will replace eventually.
  CodeActionSign = { ctermfg = 3, fg = colors[3] },
  Underlined = { underline = true }, -- Text that stands out, HTML links
  Ignore = { ctermfg = 0, fg = colors[0] }, -- Left blank, hidden |hl-Ignore| (May be invisible here in template)
  Todo = { bold = true }, -- Anything that needs extra attention; mostly the keywords TODO FIXME and XXX
  -- }}}

  -- nvim-treesitter-context {{{
  TreesitterContext = { italic = not vim.o.termguicolors, bg = colors.pmenu, nocombine = true }, -- Line used for closed folds
  -- }}}

  -- vim-matchup {{{
  MatchParen = { ctermfg = 14, bold = true, fg = colors.bracket }, -- Character under the cursor or just before it, if it is a paired bracket, and its match. |pi_paren.txt|
  MatchWord = "Identifier",
  -- }}}

  -- fidget.nvim {{{
  FidgetNormal = { ctermbg = "NONE", ctermfg = 8, bg = "NONE", fg = colors[8] },
  FidgetAccent = { ctermbg = "NONE", ctermfg = 7, bg = "NONE", fg = colors[7] },
  FidgetIcon = { ctermbg = "NONE", ctermfg = 5, fg = colors[5] },
  -- }}}

  -- mini.nvim {{{
  MiniIndentscopeSymbol = { ctermfg = 15, fg = colors[15] },
  Clear = "Identifier",
  MiniCursorword = { underline = not vim.o.termguicolors, bg = colors.bg2 },
  MiniOperatorsExchangeFrom = "Visual",
  -- }}}

  -- vim-signify {{{
  SignifySignAdd = { ctermfg = 2, fg = colors[2] },
  SignifySignChange = { ctermfg = 3, fg = colors[3] },
  SignifySignChangeDelete = "SignifySignChange",
  SignifySignDelete = { ctermfg = 1, fg = colors[1] },
  SignifySignDeleteFirstLine = "SignifySignDelete",
  -- }}}
}

-- I want most of the groups to be same color so I'll just set everything to that
-- color and overwrite them as needed.
for group, _ in pairs(vim.api.nvim_get_hl(0, {})) do
  vim.api.nvim_set_hl(0, group, {})
end

for group, spec in pairs(groups) do
  if type(spec) == "string" then
    vim.api.nvim_set_hl(0, group, { link = spec })
  else
    vim.api.nvim_set_hl(0, group, spec)
  end
end

-- stylua: ignore end
