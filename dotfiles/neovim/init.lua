-- Enabling this will cache any lua modules that are required after this point.
-- I'm disabling it for a few reasons:
--
-- When running in a portable home, vim.loader hit the max path segment limit
-- (255): https://github.com/neovim/neovim/issues/25008
--
-- Since Nix sets the modification time of all files to the epoch, the cache
-- isn't invalidated properly.
vim.loader.enable(false)

local has_ttyin = vim.fn.has("ttyin") == 1
local has_ttyout = vim.fn.has("ttyout") == 1
IsRunningInTerminal = has_ttyout or has_ttyin

-- This needs to be set before <leader> is used in a mapping
vim.g.mapleader = " "

require("base")
require("terminal")
require("_vscode")
