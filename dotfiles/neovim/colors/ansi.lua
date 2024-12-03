vim.g.colors_name = "ansi"

local groups = {
  -- modes {{{
  Normal = { ctermbg = "NONE", ctermfg = 7 },
  Visual = { ctermfg = 3, reverse = true },
  VisualNOS = "Normal", -- Visual mode selection when vim is "Not Owning the Selection".
  -- }}}

  -- searching {{{
  Search = "Visual", -- Last search pattern highlighting (see 'hlsearch'). Also used for similar items that need to stand out.
  CurSearch = "Search", -- Highlighting a search pattern under the cursor (see 'hlsearch')
  IncSearch = "Search", -- 'incsearch' highlighting; also used for the text replaced with ":s///c"
  -- }}}

  -- diagnostics {{{
  ErrorMsg = { ctermfg = 1 }, -- Error messages on the command line
  WarningMsg = { ctermfg = 3 }, -- Warning messages
  Error = { undercurl = true, ctermfg = 1 }, -- Any erroneous construct
  Warning = { undercurl = true, ctermfg = 3 }, -- (I added this)
  NvimInternalError = { ctermfg = 1 },
  DiagnosticError = { ctermfg = 1 }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
  DiagnosticWarn = { ctermfg = 3 }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
  DiagnosticInfo = { ctermfg = 4 }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
  DiagnosticHint = { ctermfg = 4 }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
  DiagnosticOk = { ctermfg = 2 }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
  DiagnosticVirtualTextError = { bold = true, italic = true, ctermfg = 1 }, -- Used for "Error" diagnostic virtual text.
  DiagnosticVirtualTextWarn = { bold = true, italic = true, ctermfg = 3 }, -- Used for "Warn" diagnostic virtual text.
  DiagnosticVirtualTextInfo = { bold = true, italic = true, ctermfg = 4 }, -- Used for "Info" diagnostic virtual text.
  DiagnosticVirtualTextHint = { bold = true, italic = true, ctermfg = 4 }, -- Used for "Hint" diagnostic virtual text.
  DiagnosticVirtualTextOk = { bold = true, italic = true, ctermfg = 2 }, -- Used for "Ok" diagnostic virtual text.
  DiagnosticUnderlineError = "Error", -- Used to underline "Error" diagnostics.
  DiagnosticUnderlineWarn = "Warning", -- Used to underline "Warn" diagnostics.
  DiagnosticUnderlineInfo = { ctermfg = 4, undercurl = true }, -- Used to underline "Info" diagnostics.
  DiagnosticUnderlineHint = { ctermfg = 4, undercurl = true }, -- Used to underline "Hint" diagnostics.
  DiagnosticUnderlineOk = { ctermfg = 2, undercurl = true }, -- Used to underline "Ok" diagnostics.
  DiagnosticFloatingError = "DiagnosticError", -- Used to color "Error" diagnostic messages in diagnostics float. See |vim.diagnostic.open_float()|
  DiagnosticFloatingWarn = "DiagnosticWarn", -- Used to color "Warn" diagnostic messages in diagnostics float.
  DiagnosticFloatingInfo = "DiagnosticInfo", -- Used to color "Info" diagnostic messages in diagnostics float.
  DiagnosticFloatingHint = "DiagnosticHint", -- Used to color "Hint" diagnostic messages in diagnostics float.
  DiagnosticFloatingOk = "DiagnosticOk", -- Used to color "Ok" diagnostic messages in diagnostics float.

  DiagnosticUnnecessary = { ctermfg = 8 },
  -- }}}

  -- float {{{
  NormalFloat = "Normal", -- Normal text in floating windows.
  FloatBorder = { ctermfg = 8 }, -- Border of floating windows.
  FloatTitle = { ctermfg = 6, bold = true }, -- Title of floating windows.
  -- }}}

  -- syntax groups {{{
  Comment = { ctermfg = 8, italic = true }, -- Any comment

  Statement = { ctermfg = 7 }, -- (*) Any statement
  -- Have to use 7 instead of "NONE" because when one language is embedded in
  -- another, like bash code in a github action yaml, the string color was being used
  Conditional = { ctermfg = 7, bold = true }, --   if, then, else, endif, switch, etc.
  Repeat = "Conditional", --   for, do, while, etc.
  Label = "Conditional", --   case, default, etc.
  Operator = "Statement", --   "sizeof", "+", "*", etc.
  Keyword = "Conditional", --   any other keyword
  Exception = "Conditional", --   try, catch, throw

  Identifier = "Normal", -- (*) Any variable name
  Function = "Identifier", --   Function name (also: methods for classes)

  Special = "Normal", -- (*) Any special symbol
  SpecialChar = "Special", --   Special character in a constant
  Tag = "Identifier", --   You can use CTRL-] on this
  Delimiter = "Identifier", --   Character that needs attention
  SpecialComment = "Special", --   Special things inside a comment (e.g. '\n')
  Debug = "Special", --   Debugging statements
  SpecialKey = "Special", -- Unprintable characters: text displayed differently from what it really is. But not 'listchars' whitespace. |hl-Whitespace|

  PreProc = "Special", -- (*) Generic Preprocessor
  Include = "PreProc", --   Preprocessor #include
  Define = "PreProc", --   Preprocessor #define
  Macro = "PreProc", --   Same as Define
  PreCondit = "PreProc", --   Preprocessor #if, #else, #endif, etc.

  Type = "Identifier", -- (*) int, long, char, etc.
  StorageClass = "Type", --   static, register, volatile, etc.
  Structure = "Type", --   struct, union, enum, etc.
  Typedef = "Type", --   A typedef

  Constant = "Identifier", -- (*) Any constant
  String = { ctermfg = 6 }, --   A string constant: "this is a string"
  Character = "String", --   A character constant: 'c', '\n'
  Number = "Identifier", --   A number constant: 234, 0xff
  Boolean = "Identifier", --   A boolean constant: TRUE, false
  Float = "Identifier", --   A floating point constant: 2.3e10
  -- }}}

  -- diffs {{{
  DiffAdd = { ctermfg = 2, reverse = true }, -- Diff mode: Added line |diff.txt|
  DiffChange = { ctermfg = 3, reverse = true }, -- Diff mode: Changed line |diff.txt|
  DiffDelete = { ctermfg = 1, reverse = true }, -- Diff mode: Deleted line |diff.txt|
  DiffText = { ctermfg = 15, reverse = true }, -- Diff mode: Changed text within a changed line |diff.txt|
  diffAdded = "DiffAdd",
  diffRemoved = "DiffDelete",
  diffChanged = "DiffChange",
  -- }}}

  -- line numbers {{{
  LineNr = { ctermfg = 8 }, -- Line number for ":number" and ":#" commands, and when 'number' or 'relativenumber' option is set.
  LineNrAbove = "LineNr", -- Line number for when the 'relativenumber' option is set, above the cursor line
  LineNrBelow = "LineNrAbove", -- Line number for when the 'relativenumber' option is set, below the cursor line
  -- }}}

  -- cursorline {{{
  CursorLine = { underline = true }, -- Screen-line at the cursor, when 'cursorline' is set. Low-priority if foreground (ctermfg OR guifg) is not set.
  CursorLineNr = { bold = true }, -- Like LineNr when 'cursorline' or 'relativenumber' is set for the cursor line.
  -- }}}

  -- statusline {{{
  status_line_mode = { ctermfg = 15, reverse = true, bold = true }, -- Status line of current window
  StatusLine = { ctermfg = 15, reverse = true }, -- Status line of current window
  StatusLineNormal = { ctermbg = "NONE", ctermfg = 7, nocombine = true },
  StatusLineFill = { ctermbg = 15, ctermfg = 15 },
  StatusLineSeparator = { ctermfg = 0, bold = true },
  StatusLineErrorText = { ctermfg = 1, nocombine = true },
  StatusLineWarningText = { ctermfg = 3, nocombine = true },
  StatusLineStandoutText = "StatusLineWarningText",
  StatusLineInfoText = { ctermfg = 4, nocombine = true },
  StatusLineHintText = { ctermfg = 4, nocombine = true },
  StatusLineNC = "StatusLine", -- Status lines of not-current windows. Note: If this is equal to "StatusLine" Vim will use "^^^" in the status line of the current window.
  StatusLineRecordingIndicator = { ctermfg = 1, nocombine = true },
  StatusLineShowcmd = "StatusLine",
  StatusLinePowerlineOuter = { ctermfg = 15, nocombine = true },
  StatusLinePowerlineInner = { ctermfg = 15, reverse = true },
  -- }}}

  -- LSP {{{
  LspInfoBorder = "FloatBorder",
  LspInlayHint = { bold = true, italic = true, ctermfg = 15 },
  LspCodeLens = "LspInlayHint", -- Used to color the virtual text of the codelens. See |nvim_buf_set_extmark()|.
  LspCodeLensSeparator = { bold = true, italic = true, ctermfg = 8 }, -- Used to color the separator between two or more code lens.
  LspReferenceTarget = { ctermfg = "NONE", ctermbg = "NONE" },
  -- }}}

  -- pmenu (autocomplete) {{{
  Pmenu = "CmpNormal", -- Popup menu: Normal item.
  PmenuSel = "CmpCursorLine", -- Popup menu: Selected item.
  PmenuKind = "CmpItemKind", -- Popup menu: Normal item "kind"
  PmenuKindSel = "PmenuSel", -- Popup menu: Selected item "kind"
  PmenuExtra = "PmenuKind", -- Popup menu: Normal item "extra text"
  PmenuExtraSel = "PmenuKindSel", -- Popup menu: Selected item "extra text"
  PmenuSbar = "Pmenu", -- Popup menu: Scrollbar.
  PmenuThumb = { ctermbg = 7 }, -- Popup menu: Thumb of the scrollbar.
  -- }}}

  -- Tree-Sitter {{{
  ["@attribute"] = "Statement", -- attribute annotations (e.g. Python decorators)
  ["@comment.documentation"] = "Comment",
  ["@comment.error"] = { italic = true, ctermfg = 1, bold = true },
  ["@comment.note"] = { italic = true, ctermfg = 4, bold = true },
  ["@comment.todo"] = { italic = true, ctermfg = 3, bold = true },
  ["@comment.warning"] = { italic = true, ctermfg = 3, bold = true },
  ["@diff.delta"] = "DiffChange",
  ["@diff.minus"] = "DiffDelete",
  ["@diff.plus"] = "DiffAdd",
  ["@function.call"] = "Function",
  ["@function.method"] = "Function",
  ["@function.method.call"] = "Function",
  ["@keyword.conditional"] = "Keyword",
  ["@keyword.conditional.ternary"] = "Keyword",
  ["@keyword.coroutine"] = "Keyword",
  ["@keyword.debug"] = "Keyword",
  ["@keyword.directive"] = "Statement",
  ["@keyword.directive.define"] = "Keyword",
  ["@keyword.exception"] = "Keyword",
  ["@keyword.function"] = "Keyword",
  ["@keyword.import"] = "Keyword",
  ["@keyword.operator"] = "Keyword",
  ["@keyword.repeat"] = "Keyword",
  ["@keyword.return"] = "Keyword",
  ["@keyword.storage"] = "Keyword",
  ["@markup.environment"] = "Structure",
  ["@markup.heading"] = "Title",
  ["@markup.italic"] = { italic = true },
  ["@markup.link"] = { underline = true, ctermfg = 4 },
  ["@markup.link.label"] = "@markup.link",
  ["@markup.link.url"] = "@markup.link",
  ["@markup.list"] = "Normal",
  ["@markup.list.checked"] = "Normal",
  ["@markup.list.unchecked"] = "Normal",
  ["@markup.math"] = "Number",
  ["@markup.quote"] = "Normal",
  ["@markup.raw"] = "Normal",
  ["@markup.raw.block"] = "Normal",
  ["@markup.strikethrough"] = "Normal",
  ["@markup.strong"] = { bold = true },
  ["@markup.underline"] = "Underlined",
  ["@module"] = "Normal",
  ["@module.builtin"] = "Normal",
  ["@punctuation"] = "Normal",
  ["@punctuation.bracket.luap"] = "Statement",
  ["@punctuation.delimiter.luap"] = "Statement",
  ["@punctuation.special"] = "Statement",
  ["@comment"] = "Comment", -- Comment
  ["@constant"] = "Constant", -- Constant
  ["@constant.builtin"] = "Constant", -- Special
  ["@constant.macro"] = "Define", -- Define
  ["@string"] = "String", -- String
  ["@string.documentation"] = "String",
  ["@string.regexp"] = "String",
  ["@string.escape"] = "Statement", -- SpecialChar
  ["@string.special"] = "Statement", -- SpecialChar
  ["@string.special.path"] = "String",
  ["@string.special.symbol"] = "Statement",
  ["@string.special.url"] = "Underlined",
  ["@string.special.url.comment"] = { italic = true, underline = true },
  ["@string.documentation.python"] = "Comment",
  ["@character"] = "Character", -- Character
  ["@character.special"] = "SpecialChar", -- SpecialChar
  ["@number"] = "Number", -- Number
  ["@number.float"] = "Number",
  ["@boolean"] = "Boolean", -- Boolean
  ["@function"] = "Function", -- Function
  ["@function.builtin"] = "Normal", -- Special
  ["@function.macro"] = "Macro", -- Macro
  ["@property"] = "Identifier", -- Identifier
  ["@constructor"] = "Identifier", -- Special
  ["@label"] = "Label", -- Label
  ["@operator"] = "Operator", -- Operator
  ["@keyword"] = "Keyword", -- Keyword
  ["@variable"] = "Identifier", -- Identifier
  ["@variable.builtin"] = "@variable",
  ["@variable.member"] = "@variable",
  ["@variable.parameter"] = "@variable",
  ["@variable.parameter.bash"] = "@variable",
  ["@variable.parameter.builtin"] = "Statement",
  ["@type"] = "Type", -- Type
  ["@type.definition"] = "Typedef", -- Typedef
  ["@type.builtin"] = "Normal",
  ["@type.qualifier"] = "Statement",
  ["@tag"] = "Tag",
  ["@tag.builtin"] = "Normal",
  ["@tag.attribute"] = "Tag",
  ["@tag.delimiter"] = "Delimiter",
  ["@attribute.builtin.python"] = "Normal",
  -- }}}

  -- misc. {{{
  Conceal = { ctermfg = 8 }, -- Placeholder characters substituted for concealed text (see 'conceallevel')
  Directory = { ctermfg = 4 }, -- Directory names (and other special names in listings)
  EndOfBuffer = "Normal", -- Filler lines (~) after the end of the buffer. By default, this is highlighted like |hl-NonText|.
  Folded = { bold = true, italic = true }, -- Line used for closed folds
  FoldColumn = { ctermfg = 8 }, -- 'foldcolumn'
  SignColumn = "Normal", -- Column where |signs| are displayed
  Substitute = "Search", -- |:substitute| replacement text highlighting
  ModeMsg = "Normal", -- 'showmode' message (e.g., "-- INSERT -- ")
  MsgArea = "StatusLine", -- Area for messages and cmdline
  MsgSeparator = "Normal", -- Separator for scrolled messages, `msgsep` flag of 'display'
  MoreMsg = "Normal", -- |more-prompt|
  NonText = { ctermfg = 15 }, -- '@' at the end of the window, characters from 'showbreak' and other characters that do not really exist in the text (e.g., ">" displayed when a double-wide character doesn't fit at the end of the line). See also |hl-EndOfBuffer|.
  Question = "Normal", -- |hit-enter| prompt and yes/no questions
  SpellBad = "Error", -- Word that is not recognized by the spellchecker. |spell| Combined with the highlighting used otherwise.
  SpellCap = "Warning", -- Word that should start with a capital. |spell| Combined with the highlighting used otherwise.
  Title = "Normal", -- Titles for output from ":set all", ":autocmd" etc.
  Whitespace = { ctermfg = 15 }, -- "nbsp", "space", "tab" and "trail" in 'listchars'
  WinSeparator = { ctermfg = 8 }, -- Separator between window splits. Inherits from |hl-VertSplit| by default, which it will replace eventually.
  CodeActionSign = { ctermfg = 3 },
  Underlined = { underline = true }, -- Text that stands out, HTML links
  Ignore = { ctermfg = 0 }, -- Left blank, hidden |hl-Ignore| (May be invisible here in template)
  Todo = { ctermfg = 3, bold = true }, -- Anything that needs extra attention; mostly the keywords TODO FIXME and XXX
  -- }}}

  -- nvim-treesitter-context {{{
  TreesitterContext = { bold = true, italic = true }, -- Line used for closed folds
  -- }}}

  -- vim-matchup {{{
  MatchParen = { ctermfg = 6 }, -- Character under the cursor or just before it, if it is a paired bracket, and its match. |pi_paren.txt|
  MatchWord = { ctermfg = "NONE", underline = true },
  -- }}}

  -- nvim-cmp {{{
  CmpNormal = { ctermbg = 15, ctermfg = 0 },
  CmpItemKind = "CmpNormal",
  CmpItemMenu = "CmpItemKind",
  CmpDocumentationNormal = "Normal",
  CmpDocumentationBorder = { ctermfg = 15 },
  CmpItemAbbrMatch = { bold = true },
  CmpItemAbbrMatchFuzzy = "CmpItemAbbrMatch",
  CmpCursorLine = { ctermbg = 6, ctermfg = 0 },
  -- }}}

  -- fidget.nvim {{{
  FidgetNormal = { bold = true, italic = true, ctermbg = "NONE", ctermfg = 8 },
  FidgetAccent = { bold = true, italic = true, ctermbg = "NONE", ctermfg = 7 },
  FidgetIcon = { bold = true, italic = true, ctermbg = "NONE", ctermfg = 5 },
  -- }}}

  -- mini.nvim {{{
  MiniIndentscopeSymbol = { ctermfg = 15 },
  MiniJump2dSpot = { ctermfg = 3 },
  MiniJump2dSpotUnique = "MiniJump2dSpot",
  MiniJump2dSpotAhead = "MiniJump2dSpot",
  MiniJump2dDim = { ctermfg = 8 },
  Clear = "Normal",
  MiniCursorword = { underline = true },
  MiniOperatorsExchangeFrom = "Visual",
  -- }}}

  -- vim-signify {{{
  SignifySignAdd = { ctermfg = 2 },
  SignifySignChange = { ctermfg = 3 },
  SignifySignChangeDelete = "SignifySignChange",
  SignifySignDelete = { ctermfg = 1 },
  SignifySignDeleteFirstLine = "SignifySignDelete",
  -- }}}
}

for group, spec in pairs(groups) do
  if type(spec) == "string" then
    vim.api.nvim_set_hl(0, group, { link = spec })
  else
    vim.api.nvim_set_hl(0, group, spec)
  end
end
