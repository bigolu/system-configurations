-- vim:foldmethod=marker

-- Tips for defining colors: {{{
--
-- An empty definition `{}` will clear all styling, leaving elements looking
-- like the 'Normal' group.  To be able to link to a group, it must already be
-- defined, so you may have to reorder items as you go.
--
-- Avoid properties that resolve at runtime like 'link' and 'reverse' because
-- lush won't be able to access what the eventual value will be. For example, if
-- you use link for highlight Foo then try to access Foo.fg it won't work since
-- lush can't determine what Foo.fg will be.
-- }}}

local is_light = vim.g.colors_name == "my_light_theme"

local lush = require("lush")
local hsl = lush.hsl
-- In order for lush.nvim to give a live preview of a color scheme, the highlights needs to have a
-- certain format so I won't format them.
-- stylua: ignore
--
-- LSP/Linters mistakenly show `undefined global` errors in the spec, they may support an annotation
-- like the following. Consult your server documentation.
---@diagnostic disable: undefined-global
local theme = lush(function(injected_functions)
  local sym = injected_functions.sym
  return {
    -- terminal palette {{{
    --
    -- SYNC: terminal-color-palettes
    --
    -- If you're in the lush live preview (:Lushify) the color below will be invisible.
    t_0 { fg = hsl(is_light and "#ffffff" or "#1d2129") },
    t_1 { fg = hsl(is_light and "#cf222e" or "#BF616A") },
    t_2 { fg = hsl(is_light and "#116329" or "#A3BE8C") },
    t_3 { fg = hsl(is_light and "#e9873a" or "#EBCB8B") },
    t_4 { fg = hsl(is_light and "#0969da" or "#81A1C1") },
    t_5 { fg = hsl(is_light and "#8250df" or "#B48EAD") },
    t_6 { fg = hsl(is_light and "#1b7c83" or "#88C0D0") },
    t_7 { fg = hsl(is_light and "#1f2328" or "#D8DEE9") },
    t_8 { fg = hsl(is_light and "#808080" or "#78849b") },
    t_9 { fg = hsl(is_light and "#a40e26" or "#BF616A") },
    t_10 { fg = hsl(is_light and "#1a7f37" or "#A3BE8C") },
    t_11 { fg = hsl(is_light and "#c96765" or "#d08770") },
    t_12 { fg = hsl(is_light and "#218bff" or "#81A1C1") },
    t_13 { fg = hsl(is_light and "#a475f9" or "#B48EAD") },
    t_14 { fg = hsl(is_light and "#3192aa" or "#8FBCBB") },
    t_15 { fg = hsl(is_light and "#808080" or "#78849b") },
    -- }}}

    virtual_text { bg = is_light and t_0.fg.da(3) or t_0.fg.li(3), bold = true, },

    -- modes {{{
    Normal { bg = "NONE", fg = t_7.fg, }, -- Normal text
    -- tint.nvim needs this in order to work
    NormalNC { Normal, }, -- normal text in non-current windows
    Visual { bg = is_light and hsl("#add6ff") or t_3.fg, fg = is_light and "NONE" or t_0.fg, }, -- Visual mode selection
    VisualNOS {}, -- Visual mode selection when vim is "Not Owning the Selection".
    -- }}}

    -- searching {{{
    Search { Visual }, -- Last search pattern highlighting (see 'hlsearch'). Also used for similar items that need to stand out.
    CurSearch { Search }, -- Highlighting a search pattern under the cursor (see 'hlsearch')
    IncSearch { Search }, -- 'incsearch' highlighting; also used for the text replaced with ":s///c"
    -- }}}

    -- diagnostics {{{
    ErrorMsg { t_1 }, -- Error messages on the command line
    WarningMsg { t_3 }, -- Warning messages
    Error { undercurl = true, sp = ErrorMsg.fg, }, -- Any erroneous construct
    Warning { undercurl = true, sp = WarningMsg.fg, }, -- (I added this)
    NvimInternalError { ErrorMsg },
    -- See :h diagnostic-highlights, some groups may not be listed, submit a PR fix to lush-template!
    --
    DiagnosticError { ErrorMsg }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    DiagnosticWarn { WarningMsg }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    DiagnosticInfo { t_4, }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    DiagnosticHint { t_5 }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    DiagnosticOk { t_2 }, -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    DiagnosticVirtualTextError { virtual_text, fg = ErrorMsg.fg, }, -- Used for "Error" diagnostic virtual text.
    DiagnosticVirtualTextWarn { virtual_text, fg = WarningMsg.fg, }, -- Used for "Warn" diagnostic virtual text.
    DiagnosticVirtualTextInfo { virtual_text, fg = DiagnosticInfo.fg, }, -- Used for "Info" diagnostic virtual text.
    DiagnosticVirtualTextHint { virtual_text, fg = DiagnosticHint.fg, }, -- Used for "Hint" diagnostic virtual text.
    DiagnosticVirtualTextOk { virtual_text, fg = DiagnosticOk.fg, }, -- Used for "Ok" diagnostic virtual text.
    DiagnosticUnderlineError { Error }, -- Used to underline "Error" diagnostics.
    DiagnosticUnderlineWarn { Warning }, -- Used to underline "Warn" diagnostics.
    DiagnosticUnderlineInfo { sp = DiagnosticInfo.fg, undercurl = true }, -- Used to underline "Info" diagnostics.
    DiagnosticUnderlineHint { sp = DiagnosticHint.fg, undercurl = true }, -- Used to underline "Hint" diagnostics.
    DiagnosticUnderlineOk { sp = DiagnosticOk.fg, undercurl = true }, -- Used to underline "Ok" diagnostics.
    DiagnosticFloatingError { DiagnosticError }, -- Used to color "Error" diagnostic messages in diagnostics float. See |vim.diagnostic.open_float()|
    DiagnosticFloatingWarn { DiagnosticWarn }, -- Used to color "Warn" diagnostic messages in diagnostics float.
    DiagnosticFloatingInfo { DiagnosticInfo }, -- Used to color "Info" diagnostic messages in diagnostics float.
    DiagnosticFloatingHint { DiagnosticHint }, -- Used to color "Hint" diagnostic messages in diagnostics float.
    DiagnosticFloatingOk { DiagnosticOk }, -- Used to color "Ok" diagnostic messages in diagnostics float.
    -- }}}

    -- float {{{
    NormalFloat { }, -- Normal text in floating windows.
    FloatBorder { NormalFloat, fg = t_8.fg, }, -- Border of floating windows.
    FloatTitle { NormalFloat, fg = t_6.fg, bold = true, }, -- Title of floating windows.
    -- }}}

    -- syntax groups {{{
    -- Common vim syntax groups used for all kinds of code and markup.
    -- Commented-out groups should chain up to their preferred (*) group
    -- by default.
    --
    -- See :h group-name
    --
    -- Uncomment and edit if you want more specific syntax highlighting.

    Comment { fg = t_8.fg, italic = true }, -- Any comment

    Statement { t_4 }, -- (*) Any statement
    Conditional    { Statement, }, --   if, then, else, endif, switch, etc.
    Repeat         { Statement, }, --   for, do, while, etc.
    Label          { Statement, }, --   case, default, etc.
    Operator       { Statement, }, --   "sizeof", "+", "*", etc.
    Keyword        { Statement, }, --   any other keyword
    Exception      { Statement, }, --   try, catch, throw

    Identifier { Normal }, -- (*) Any variable name
    Function       { Identifier, }, --   Function name (also: methods for classes)

    Special { t_3, }, -- (*) Any special symbol
    SpecialChar    { Special, }, --   Special character in a constant
    Tag            { Identifier, }, --   You can use CTRL-] on this
    Delimiter      { Identifier, }, --   Character that needs attention
    SpecialComment { Special, }, --   Special things inside a comment (e.g. '\n')
    Debug          { Special, }, --   Debugging statements
    SpecialKey { Special }, -- Unprintable characters: text displayed differently from what it really is. But not 'listchars' whitespace. |hl-Whitespace|

    PreProc { Special }, -- (*) Generic Preprocessor
    Include        { PreProc, }, --   Preprocessor #include
    Define         { PreProc, }, --   Preprocessor #define
    Macro          { PreProc, }, --   Same as Define
    PreCondit      { PreProc, }, --   Preprocessor #if, #else, #endif, etc.

    Type { Identifier }, -- (*) int, long, char, etc.
    StorageClass   { Type, }, --   static, register, volatile, etc.
    Structure      { Type, }, --   struct, union, enum, etc.
    Typedef        { Type, }, --   A typedef

    Constant { Identifier }, -- (*) Any constant
    String { t_2 }, --   A string constant: "this is a string"
    Character      { String, }, --   A character constant: 'c', '\n'
    Number         { Identifier, }, --   A number constant: 234, 0xff
    Boolean        { Identifier, }, --   A boolean constant: TRUE, false
    Float          { Identifier, }, --   A floating point constant: 2.3e10
    -- }}}

    -- diffs {{{
    DiffAdd { bg = t_2.fg[is_light and 'lighten' or 'darken'](60) }, -- Diff mode: Added line |diff.txt|
    DiffChange { bg = t_3.fg[is_light and 'lighten' or 'darken'](60) }, -- Diff mode: Changed line |diff.txt|
    DiffDelete { bg = t_1.fg[is_light and 'lighten' or 'darken'](60) }, -- Diff mode: Deleted line |diff.txt|
    DiffText { bg = t_3.fg[is_light and 'lighten' or 'darken'](50) }, -- Diff mode: Changed text within a changed line |diff.txt|
    diffAdded { DiffAdd },
    diffRemoved { DiffDelete },
    diffChanged { DiffChange },
    -- }}}

    -- line numbers {{{
    LineNr { fg = t_8.fg }, -- Line number for ":number" and ":#" commands, and when 'number' or 'relativenumber' option is set.
    LineNrAbove { LineNr }, -- Line number for when the 'relativenumber' option is set, above the cursor line
    LineNrBelow { LineNrAbove }, -- Line number for when the 'relativenumber' option is set, below the cursor line
    -- }}}

    -- cursorline {{{
    CursorLine { underline = true, sp = "fg" }, -- Screen-line at the cursor, when 'cursorline' is set. Low-priority if foreground (ctermfg OR guifg) is not set.
    CursorLineNr { bold = true }, -- Like LineNr when 'cursorline' or 'relativenumber' is set for the cursor line.
    -- CursorLineFold { }, -- Like FoldColumn when 'cursorline' is set for the cursor line
    -- CursorLineSign { }, -- Like SignColumn when 'cursorline' is set for the cursor line
    -- }}}

    -- statusline {{{
    ---@diagnostic disable-next-line: redundant-parameter
    StatusLine { bg = is_light and hsl("#eceef1") or t_0.fg.lighten(6) }, -- Status line of current window
    ---@diagnostic disable-next-line: undefined-field
    StatusLineFill { StatusLine, fg = StatusLine.bg },
    StatusLineSeparator { StatusLine, fg = t_0.fg, bold = true },
    StatusLineErrorText { StatusLine, fg = ErrorMsg.fg },
    StatusLineWarningText { StatusLine, fg = WarningMsg.fg },
    StatusLineStandoutText { StatusLineWarningText },
    StatusLineInfoText { StatusLine, fg = DiagnosticInfo.fg },
    StatusLineHintText { StatusLine, fg = DiagnosticHint.fg },
    StatusLineNC { StatusLine }, -- Status lines of not-current windows. Note: If this is equal to "StatusLine" Vim will use "^^^" in the status line of the current window.
    StatusLineRecordingIndicator { StatusLine, fg = ErrorMsg.fg },
    StatusLineShowcmd { StatusLine, fg = t_6.fg },
    StatusLineDebugIndicator { StatusLine, fg = t_2.fg },
    ---@diagnostic disable-next-line: undefined-field
    StatusLinePowerlineOuter { fg = StatusLine.bg },
    StatusLinePowerlineInner { StatusLine, fg = t_0.fg },
    status_line_mode { StatusLine, bold = true },
    StatusLineModeNormal { status_line_mode, },
    StatusLineModeVisual { status_line_mode, fg = (is_light and t_4 or t_3).fg, },
    StatusLineModeInsert { status_line_mode, fg = t_6.fg, },
    StatusLineModeTerminal { status_line_mode, fg = t_2.fg, },
    StatusLineModeOther { status_line_mode, fg = t_8.fg, },
    -- }}}

    -- LSP {{{
      -- These groups are for the native LSP client and diagnostic system. Some
      -- other LSP clients may use these groups, or use their own. Consult your
      -- LSP client's documentation.

      -- See :h lsp-highlight, some groups may not be listed, submit a PR fix to lush-template!
      --
      -- LspReferenceText            { } , -- Used for highlighting "text" references
      -- LspReferenceRead            { } , -- Used for highlighting "read" references
      -- LspReferenceWrite           { } , -- Used for highlighting "write" references
      -- LspSignatureActiveParameter { } , -- Used to highlight the active parameter in the signature help. See |vim.lsp.handlers.signature_help()|.
      LspInfoBorder { FloatBorder },
      LspInlayHint { virtual_text, fg = t_0.fg[is_light and 'darken' or 'lighten'](68), },
      LspCodeLens { LspInlayHint, } , -- Used to color the virtual text of the codelens. See |nvim_buf_set_extmark()|.
      LspCodeLensSeparator { LspCodeLens, fg = t_8.fg, } , -- Used to color the seperator between two or more code lens.
      -- }}}

    Conceal { t_8 }, -- Placeholder characters substituted for concealed text (see 'conceallevel')
    Directory { t_4 }, -- Directory names (and other special names in listings)
    EndOfBuffer {}, -- Filler lines (~) after the end of the buffer. By default, this is highlighted like |hl-NonText|.
    Folded { bg = t_0.fg[is_light and 'darken' or 'lighten'](3) }, -- Line used for closed folds
    FoldColumn { fg = t_8.fg }, -- 'foldcolumn'
    TreesitterContext { bg = is_light and t_0.fg.darken(3) or t_0.fg.lighten(2) }, -- Line used for closed folds
    SignColumn {}, -- Column where |signs| are displayed
    Substitute { Search }, -- |:substitute| replacement text highlighting
    ModeMsg {}, -- 'showmode' message (e.g., "-- INSERT -- ")
    MsgArea { StatusLine }, -- Area for messages and cmdline
    MsgSeparator {}, -- Separator for scrolled messages, `msgsep` flag of 'display'
    MoreMsg {}, -- |more-prompt|
    NonText { fg = t_0.fg[is_light and 'darken' or 'lighten'](10) }, -- '@' at the end of the window, characters from 'showbreak' and other characters that do not really exist in the text (e.g., ">" displayed when a double-wide character doesn't fit at the end of the line). See also |hl-EndOfBuffer|.
    Question {}, -- |hit-enter| prompt and yes/no questions
    SpellBad { Error }, -- Word that is not recognized by the spellchecker. |spell| Combined with the highlighting used otherwise.
    SpellCap { Warning }, -- Word that should start with a capital. |spell| Combined with the highlighting used otherwise.
    Title { Normal }, -- Titles for output from ":set all", ":autocmd" etc.
    Whitespace { fg = t_0.fg[is_light and 'darken' or 'lighten'](30) }, -- "nbsp", "space", "tab" and "trail" in 'listchars'
    WinSeparator { t_8, }, -- Separator between window splits. Inherts from |hl-VertSplit| by default, which it will replace eventually.
    ColorColumn { WinSeparator },
    -- If I leave it empty, tint.nvim won't tint it, but tinting works if I explicitly set the
    -- foreground color
    WinBar { fg = 'fg', }, -- Window bar of current window
    -- tint.nvim needs this in order to work
    WinBarNC { WinBar, }, -- Window bar of not-current windows
    GitBlameVirtualText { virtual_text, fg = t_8.fg, },
    WhichKeyFloat { Normal, }, -- Normal text in floating windows.
    WhichKeyBorder { WhichKeyFloat, fg = t_8.fg, }, -- Border of floating windows.
    CodeActionSign { t_3 },
    NullLsInfoBorder { FloatBorder },
    WidgetFill { t_0 },
    Underlined { underline = true, }, -- Text that stands out, HTML links
    Ignore { t_0 }, -- Left blank, hidden |hl-Ignore| (May be invisible here in template)
    Todo { t_3, bold = true, }, -- Anything that needs extra attention; mostly the keywords TODO FIXME and XXX
    VirtColumn { NonText, },
    LuaSnipInlayHint { virtual_text, fg = Special.fg },
    QuickfixPreview { Search, nocombine = true },
    MiniOperatorsExchangeFrom { Visual },

    -- nvim-cmp {{{
    CmpNormal { bg = t_0.fg[is_light and 'darken' or 'lighten'](6) },
    CmpItemKind { fg = CmpNormal.bg[is_light and 'darken' or 'lighten'](55) },
    CmpItemMenu { CmpItemKind },
    CmpDocumentationNormal { bg = CmpNormal.bg[is_light and 'darken' or 'lighten'](1), },
    CmpDocumentationBorder { CmpDocumentationNormal, fg = CmpDocumentationNormal.bg, },
    CmpItemAbbrMatch { t_6 },
    CmpItemAbbrMatchFuzzy { CmpItemAbbrMatch },
    CmpCursorLine { CmpItemAbbrMatch, reverse = true },
    -- }}}

    -- pmenu (autocomplete) {{{
    Pmenu { CmpNormal }, -- Popup menu: Normal item.
    PmenuSel { CmpCursorLine }, -- Popup menu: Selected item.
    PmenuKind { CmpItemKind }, -- Popup menu: Normal item "kind"
    PmenuKindSel { PmenuSel }, -- Popup menu: Selected item "kind"
    PmenuExtra { PmenuKind }, -- Popup menu: Normal item "extra text"
    PmenuExtraSel { PmenuKindSel }, -- Popup menu: Selected item "extra text"
    PmenuSbar { Pmenu }, -- Popup menu: Scrollbar.
    PmenuThumb { bg = PmenuSbar.bg[is_light and 'darken' or 'lighten'](30) }, -- Popup menu: Thumb of the scrollbar.
    -- }}}

    -- fidget.nvim {{{
    FidgetNormal { virtual_text, bg = "NONE", fg = t_8.fg, },
    FidgetAccent { FidgetNormal, fg = Normal.fg },
    FidgetIcon { FidgetNormal, fg = t_5.fg },
    -- }}}

    -- mini.nvim {{{
    MiniIndentscopeSymbol { fg = t_0.fg[is_light and 'darken' or 'lighten'](23), },
    MiniJump2dSpot { t_3 },
    MiniJump2dSpotUnique { MiniJump2dSpot },
    MiniJump2dSpotAhead { MiniJump2dSpot },
    MiniJump2dDim { t_8 },
    Clear { },
    MiniCursorword { bold = true, },
    -- }}}

    QuickFixLine { }, -- Current |quickfix| item in the quickfix window. Combined with |hl-CursorLine| when the cursor is there.
    QuickFixEntryUnderline { underline = true, sp = MiniCursorword.bg, nocombine = true, },
    QuickfixFold { bold = true, },
    qfFileName { Normal, },
    qfLineNr { qfFileName, },
    QuickfixBorderNotCurrent { Ignore },
    QuickfixTitleNotCurrent { Normal },
    MatchParen { MiniCursorword, fg = t_5.fg, }, -- Character under the cursor or just before it, if it is a paired bracket, and its match. |pi_paren.txt|

    -- nvim-notify {{{
    -- nvim-notify requires the bg be a hex value since it's transparency during the fade animation
    -- will be computed with it
    NotifyBackground { bg = t_0.fg },
    NotifyERRORTitle { fg = ErrorMsg.fg },
    NotifyERRORBorder { NotifyERRORTitle },
    NotifyERRORIcon { NotifyERRORTitle },
    NotifyWARNTitle { fg = WarningMsg.fg },
    NotifyWARNBorder { NotifyWARNTitle },
    NotifyWARNIcon { NotifyWARNTitle },
    NotifyINFOTitle { fg = DiagnosticInfo.fg },
    NotifyINFOBorder { NotifyINFOTitle },
    NotifyINFOIcon { NotifyINFOTitle },
    NotifyDEBUGTitle { fg = t_8.fg },
    NotifyDEBUGBorder { NotifyDEBUGTitle },
    NotifyDEBUGIcon { NotifyDEBUGTitle },
    NotifyTRACETitle { fg = t_5.fg },
    NotifyTRACEBorder { NotifyTRACETitle },
    NotifyTRACEIcon { NotifyTRACETitle },
    -- }}}

    -- Tree-Sitter {{{
    --
    -- See :h treesitter-highlight-groups, some groups may not be listed,
    -- submit a PR fix to lush-template!
    --
    -- Tree-Sitter groups are defined with an "@" symbol, which must be
    -- specially handled to be valid lua code, we do this via the special
    -- sym function. The following are all valid ways to call the sym function,
    -- for more details see https://www.lua.org/pil/5.html
    --
    -- sym("@text.literal")
    -- sym('@text.literal')
    -- sym"@text.literal"
    -- sym'@text.literal'
    --
    -- For more information see https://github.com/rktjmp/lush.nvim/issues/109

    sym"@attribute" { Statement }, -- attribute annotations (e.g. Python decorators)
    sym"@comment.documentation" { Comment },
    sym"@comment.error" { Comment, fg = Error.fg, bold = true, },
    sym"@comment.note" { Comment, fg = DiagnosticInfo.fg, bold = true, },
    sym"@comment.todo" { Comment, fg = Todo.fg, bold = true, },
    sym"@comment.warning" { Comment, fg = Warning.fg, bold = true, },
    sym"@diff.delta" { DiffChange },
    sym"@diff.minus" { DiffDelete },
    sym"@diff.plus" { DiffAdd },
    sym"@function.call" { Function },
    sym"@function.method" { Function },
    sym"@function.method.call" { Function },
    sym"@keyword.conditional" { Keyword },
    sym"@keyword.conditional.ternary" { Keyword },
    sym"@keyword.coroutine" { Keyword },
    sym"@keyword.debug" { Keyword },
    sym"@keyword.directive" { Keyword },
    sym"@keyword.directive.define" { Keyword },
    sym"@keyword.exception" { Keyword },
    sym"@keyword.function" { Keyword },
    sym"@keyword.import" { Keyword },
    sym"@keyword.operator" { Keyword },
    sym"@keyword.repeat" { Keyword },
    sym"@keyword.return" { Keyword },
    sym"@keyword.storage" { Keyword },
    sym"@markup.environment" { Structure },
    sym"@markup.heading" { Title },
    sym"@markup.italic" { italic = true, },
    sym"@markup.link" { Underlined, fg = t_4.fg, },
    sym"@markup.link.label" { sym"@markup.link", },
    sym"@markup.link.url" { sym"@markup.link", },
    sym"@markup.list" { },
    sym"@markup.list.checked" { },
    sym"@markup.list.unchecked" { },
    sym"@markup.math" { Number, },
    sym"@markup.quote" { },
    sym"@markup.raw" { },
    sym"@markup.raw.block" { },
    sym"@markup.strikethrough" { },
    sym"@markup.strong" { bold = true, },
    sym"@markup.underline" { Underlined },
    sym"@module" { },
    sym"@module.builtin" { },
    sym"@punctuation" { Normal },
    sym"@punctuation.bracket.luap" { Statement },
    sym"@punctuation.delimiter.luap" { Statement },
    sym"@punctuation.special" { Statement },
    sym"@comment" { Comment }, -- Comment
    sym"@constant" { Constant }, -- Constant
    sym"@constant.builtin" { Constant }, -- Special
    sym"@constant.macro" { Define }, -- Define
    sym"@string" { String }, -- String
    sym"@string.documentation" { String },
    sym"@string.regexp" { String },
    sym"@string.escape" { Statement }, -- SpecialChar
    sym"@string.special" { Statement }, -- SpecialChar
    sym"@string.special.path" { String },
    sym"@string.special.symbol" { Statement },
    sym"@string.special.url" { Underlined, },
    sym"@string.special.url.comment" { Comment, fg = Underlined.fg, underline = true, },
    sym"@character" { Character }, -- Character
    sym"@character.special" { SpecialChar }, -- SpecialChar
    sym"@number" { Number }, -- Number
    sym"@number.float" { Number },
    sym"@boolean" { Boolean }, -- Boolean
    sym"@function" { Function }, -- Function
    sym"@function.builtin" { }, -- Special
    sym"@function.macro" { Macro }, -- Macro
    sym"@property" { Identifier }, -- Identifier
    sym"@constructor" { Identifier }, -- Special
    sym"@label" { Label }, -- Label
    sym"@operator" { Operator }, -- Operator
    sym"@keyword" { Keyword }, -- Keyword
    sym"@variable" { Identifier }, -- Identifier
    sym"@variable.builtin" { sym"@variable" },
    sym"@variable.member" { sym"@variable" },
    sym"@variable.parameter" { sym"@variable" },
    sym"@variable.parameter.bash" { String },
    sym"@variable.parameter.builtin" { Statement },
    sym"@type" { Type }, -- Type
    sym"@type.definition" { Typedef }, -- Typedef
    sym"@type.builtin" { },
    sym"@type.qualifier" { Statement },
    sym"@tag" { Tag },
    sym"@tag.builtin" { },
    sym"@tag.attribute" { Tag },
    sym"@tag.delimiter" { Delimiter },
    -- }}}

    -- dropbar.nvim {{{
      DropBarCurrentContext { t_6 },
      DropBarMenuCurrentContext { t_6, nocombine= true },
      DropBarHover { DropBarCurrentContext },
      DropBarIconHover { DropBarMenuCurrentContext },
      DropBarMenuHoverEntry { t_6 },
      DropBarIconUIIndicator { fg = CmpItemKind.fg },
      DropBarMenuHoverIcon { DropBarMenuHoverEntry, },
      DropBarMenuNormalFloat { CmpNormal },
      DropBarMenuCursor { DropBarMenuNormalFloat, fg = DropBarMenuNormalFloat.bg, blend = 100, },
      DropBarPreview { MiniCursorword },
      DropBarIconUISeparator { t_8 },
      DropBarIconUISeparatorMenu { CmpItemKind },
      DropBarIconKindArray { Identifier },
      DropBarIconKindBoolean { DropBarIconKindArray },
      DropBarIconKindBreakStatement { DropBarIconKindArray },
      DropBarIconKindCall { DropBarIconKindArray },
      DropBarIconKindCaseStatement { DropBarIconKindArray },
      DropBarIconKindClass { DropBarIconKindArray },
      DropBarIconKindConstant { DropBarIconKindArray },
      DropBarIconKindConstructor { DropBarIconKindArray },
      DropBarIconKindContinueStatement { DropBarIconKindArray },
      DropBarIconKindDeclaration { DropBarIconKindArray },
      DropBarIconKindDelete { DropBarIconKindArray },
      DropBarIconKindDoStatement { DropBarIconKindArray },
      DropBarIconKindElseStatement { DropBarIconKindArray },
      DropBarIconKindEnum { DropBarIconKindArray },
      DropBarIconKindEnumMember { DropBarIconKindArray },
      DropBarIconKindEvent { DropBarIconKindArray },
      DropBarIconKindField { DropBarIconKindArray },
      DropBarIconKindFile { DropBarIconKindArray },
      DropBarIconKindFolder { DropBarIconKindArray },
      DropBarIconKindForStatement { DropBarIconKindArray },
      DropBarIconKindFunction { DropBarIconKindArray },
      DropBarIconKindH1Marker { DropBarIconKindArray },
      DropBarIconKindH2Marker { DropBarIconKindArray },
      DropBarIconKindH3Marker { DropBarIconKindArray },
      DropBarIconKindH4Marker { DropBarIconKindArray },
      DropBarIconKindH5Marker { DropBarIconKindArray },
      DropBarIconKindH6Marker { DropBarIconKindArray },
      DropBarIconKindIdentifier { DropBarIconKindArray },
      DropBarIconKindIfStatement { DropBarIconKindArray },
      DropBarIconKindInterface { DropBarIconKindArray },
      DropBarIconKindKeyword { DropBarIconKindArray },
      DropBarIconKindList { DropBarIconKindArray },
      DropBarIconKindMacro { DropBarIconKindArray },
      DropBarIconKindMarkdownH1 { DropBarIconKindArray },
      DropBarIconKindMarkdownH2 { DropBarIconKindArray },
      DropBarIconKindMarkdownH3 { DropBarIconKindArray },
      DropBarIconKindMarkdownH4 { DropBarIconKindArray },
      DropBarIconKindMarkdownH5 { DropBarIconKindArray },
      DropBarIconKindMarkdownH6 { DropBarIconKindArray },
      DropBarIconKindMethod { DropBarIconKindArray },
      DropBarIconKindModule { DropBarIconKindArray },
      DropBarIconKindNamespace { DropBarIconKindArray },
      DropBarIconKindNull { DropBarIconKindArray },
      DropBarIconKindNumber { DropBarIconKindArray },
      DropBarIconKindObject { DropBarIconKindArray },
      DropBarIconKindOperator { DropBarIconKindArray },
      DropBarIconKindPackage { DropBarIconKindArray },
      DropBarIconKindPair { DropBarIconKindArray },
      DropBarIconKindProperty { DropBarIconKindArray },
      DropBarIconKindReference { DropBarIconKindArray },
      DropBarIconKindRepeat { DropBarIconKindArray },
      DropBarIconKindScope { DropBarIconKindArray },
      DropBarIconKindSpecifier { DropBarIconKindArray },
      DropBarIconKindStatement { DropBarIconKindArray },
      DropBarIconKindString { DropBarIconKindArray },
      DropBarIconKindStruct { DropBarIconKindArray },
      DropBarIconKindSwitchStatement { DropBarIconKindArray },
      DropBarIconKindTerminal { DropBarIconKindArray },
      DropBarIconKindType { DropBarIconKindArray },
      DropBarIconKindTypeParameter { DropBarIconKindArray },
      DropBarIconKindUnit { DropBarIconKindArray },
      DropBarIconKindValue { DropBarIconKindArray },
      DropBarIconKindVariable { DropBarIconKindArray },
      DropBarIconKindWhileStatement { DropBarIconKindArray },
      -- }}}

    -- vim-signify {{{
      SignifyAdd { fg = t_2.fg },
      SignifyDelete { fg = t_1.fg },
      SignifyChange { fg = t_3.fg },
      -- I'm setting all of these so that the signify signs will be added to the sign column, but
      -- NOT be visible. I don't want them to be visible because I already change the color of my
      -- statuscolumn border to indicate git changes. I want them to be added to the sign column so I
      -- know where to color my statuscolumn border.
      SignifySignAdd { Ignore, },
      SignifySignChange { Ignore, },
      SignifySignChangeDelete { Ignore, },
      SignifySignDelete { Ignore, },
      SignifySignDeleteFirstLine { Ignore, },
      -- }}}
  }
end)

return theme

-- vi:nowrap
