vim.opt.matchpairs:append("<:>")

-- select the text that was just pasted
vim.keymap.set({ "n" }, "gp", function()
  vim.api.nvim_buf_set_mark(vim.api.nvim_get_current_buf(), "y", LastPasteStartLine, LastPasteStartCol, {})
  vim.api.nvim_buf_set_mark(vim.api.nvim_get_current_buf(), "z", LastPasteEndLine, LastPasteEndCol, {})
  return string.format("`y%s`z", (LastPasteStartLine == LastPasteEndLine) and "v" or "V")
end, {
  desc = "Last pasted text",
  expr = true,
})

-- move to left and right side of last selection
vim.keymap.set({ "n" }, "[v", "'<", {
  desc = "Start of last selection",
})
vim.keymap.set({ "n" }, "]v", "'>", {
  desc = "End of last selection",
})

-- move to left and right side of last yank
vim.keymap.set({ "n" }, "[y", "'[", {
  desc = "Start of last yank",
})
vim.keymap.set({ "n" }, "]y", "']", {
  desc = "End of last yank",
})

vim.keymap.set({ "n", "x" }, "j", "gj")
vim.keymap.set({ "n", "x" }, "k", "gk")

-- move six lines/columns at a time by holding ctrl and a directional key. Reasoning for
-- using 6 here:
-- https://nanotipsforvim.prose.sh/vertical-navigation-%E2%80%93-without-relative-line-numbers
vim.keymap.set({ "n", "x" }, "<C-j>", "6gj")
vim.keymap.set({ "n", "x" }, "<C-k>", "6gk")
vim.keymap.set({ "n", "x" }, "<C-h>", "6h")
vim.keymap.set({ "n", "x" }, "<C-l>", "6l")

-- Using the paragraph motions won't add to the jump stack
vim.keymap.set({ "n" }, "}", [[<Cmd>keepjumps normal! }<CR>]], {
  desc = "End of paragraph",
})
vim.keymap.set({ "n" }, "{", [[<Cmd>keepjumps normal! {<CR>]], {
  desc = "Start of paragraph",
})
vim.keymap.set({ "n", "x" }, "]p", "}", { remap = true, desc = "End of paragraph" })
vim.keymap.set({ "n", "x" }, "[p", "{", { remap = true, desc = "Start of paragraph" })

-- Move to beginning and end of line
vim.keymap.set({ "n" }, "<C-e>", "$", {
  desc = "End of line",
})
vim.keymap.set({ "i" }, "<C-a>", "<ESC>^i", {
  desc = "First non-blank of line [start]",
})
vim.keymap.set({ "i" }, "<C-e>", "<ESC>$a", {
  desc = "End of line",
})
local function c_a(buffer)
  vim.keymap.set({ "n" }, "<C-a>", "^", {
    desc = "First non-blank of line [start]",
    buffer = buffer,
  })
end
c_a()
vim.api.nvim_create_autocmd("FileType", {
  pattern = "gitrebase",
  callback = function()
    c_a(true)
  end,
})

-- jeetsukumaran/vim-indentwise
-- Motions for levels of indentation
vim.keymap.set(
  "",
  "[-",
  "<Plug>(IndentWisePreviousLesserIndent)",
  { remap = true, desc = "Last line with lower indent" }
)
vim.keymap.set(
  "",
  "[+",
  "<Plug>(IndentWisePreviousGreaterIndent)",
  { remap = true, desc = "Last line with higher indent" }
)
vim.keymap.set(
  "",
  "[=",
  "<Plug>(IndentWisePreviousEqualIndent)",
  { remap = true, desc = "Last block with equal indent" }
)
vim.keymap.set("", "]-", "<Plug>(IndentWiseNextLesserIndent)", { remap = true, desc = "Next line with lower indent" })
vim.keymap.set("", "]+", "<Plug>(IndentWiseNextGreaterIndent)", { remap = true, desc = "Next line with higher indent" })
vim.keymap.set("", "]=", "<Plug>(IndentWiseNextEqualIndent)", { remap = true, desc = "Next block with equal indent" })
vim.g.indentwise_suppress_keymaps = 1

-- andymass/vim-matchup
--
-- Don't display off-screen matches in my statusline or a popup window
vim.g.matchup_matchparen_offscreen = {}
-- These two highlight the surroundings that the cursor is currently contained within
vim.g.matchup_matchparen_deferred = 1
vim.g.matchup_matchparen_hi_surround_always = 1
vim.keymap.set({ "n", "x" }, ";", "%", { remap = true })
vim.keymap.set({ "n", "x" }, "g;", "g%", { remap = true })
vim.keymap.set({ "n", "x" }, "];", "]%", { remap = true })
vim.keymap.set({ "n", "x" }, "[;", "[%", { remap = true })
vim.keymap.set({ "n", "x" }, "z;", "z%", { remap = true })

-- bkad/CamelCaseMotion
vim.g.camelcasemotion_key = ","

local function marker_fold_object()
  -- excluded first and last lines for marker folds
  if vim.wo.foldmethod == "marker" then
    return ":<C-U>silent!normal![zjV]zk<CR>"
  else
    return ":<C-U>silent!normal![zV]z<CR>"
  end
end
vim.keymap.set({ "x" }, "iz", marker_fold_object, {
  desc = "Inner fold",
  expr = true,
})
vim.keymap.set({ "o" }, "iz", ":normal viz<CR>", {
  desc = "Inner fold",
})
vim.keymap.set({ "x" }, "az", ":<C-U>silent!normal![zV]z<CR>", {
  desc = "Outer fold",
})
vim.keymap.set({ "o" }, "az", ":normal vaz<CR>", {
  desc = "Outer fold",
})
