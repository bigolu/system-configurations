IsRunningInTerminal = (vim.fn.has("ttyout") == 1) or (vim.fn.has("ttyin") == 1)
-- This needs to be set before <leader> is used in a mapping
vim.g.mapleader = " "

require("base.filetype-settings")
require("base.macros")
require("base.mini")
require("base.misc")
require("base.motions-and-textobjects")
require("base.operators")
require("base.searching")
