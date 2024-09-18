-- Enabling this will cache any lua modules that are required after this point.
-- I'm disabling it for a few reasons:
--
-- When running in a portable home, vim.loader hit the max path segment limit
-- (255): https://github.com/neovim/neovim/issues/25008
--
-- Since Nix sets the modification time of all files to the epoch, the cache
-- isn't invalidated properly.
vim.loader.disable()

-- Every time we enter a buffer, reset the fold options. This avoids the issue
-- where you set a foldmethod maybe because the attached LSP server supports
-- it, but then switch to another buffer and the foldmethod is still set to
-- LSP. Your other fold providers think that LSP folding is active and don't
-- override it. With this autocmd, there will never be "stale" fold options
-- because they will always get reset. Though this means that all fold providers
-- have to set fold options every time the buffer is entered. I expected this
-- to be a problem with modelines, but it seems to work. I put the autocmd here
-- because it needs to fire before the autocmds of any fold providers.
vim.api.nvim_create_autocmd({ "BufRead" }, {
  callback = function()
    vim.cmd([[
      setlocal foldmethod&
      setlocal foldexpr&
    ]])
  end,
})

local has_ttyin = vim.fn.has("ttyin") == 1
local has_ttyout = vim.fn.has("ttyout") == 1
IsRunningInTerminal = has_ttyout or has_ttyin

-- My configuration is mixed in with my plugin definitions so I have to do
-- everything in here.
require("plug").load_plugins(function()
  require("base")
  require("terminal")
  require("_vscode")
  require("browser")
end)
