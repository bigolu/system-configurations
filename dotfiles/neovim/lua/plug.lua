-- Wrapper for vim-plug with a few new features.

local M = {}

vim.g.plug_window = "vertical topleft new"
vim.g.plug_pwindow = "above 12new"

-- Functions to be called after a plugin is loaded to configure it.
local configs = {}

local function plug(repo, config)
  vim.fn["plug#"](repo)
  if config ~= nil then
    table.insert(configs, config)
  end
end

local function plug_begin()
  -- expose the Plug function globally
  _G["Plug"] = plug

  -- To suppress the 'no git executable' warning
  vim.cmd([[
    silent! call plug#begin()
  ]])
end

local function plug_end()
  vim.fn["plug#end"]()

  _G["Plug"] = nil

  -- This way code can be run after plugins are loaded, but before 'VimEnter'
  vim.api.nvim_exec_autocmds("User", { pattern = "PlugEndPost" })

  for _, config in ipairs(configs) do
    config()
  end
end

-- vim-plug enables syntax highlighting if it isn't already enabled, but I
-- don't want it since I use treesitter. This will make vim-plug think it's
-- already on so it won't enable it.
local function run_with_faked_syntax_on(fn)
  vim.cmd.syntax("off")
  vim.g.syntax_on = true
  fn()
  vim.g.syntax_on = false
end

function M.load_plugins(set_plugins)
  run_with_faked_syntax_on(function()
    plug_begin()
    set_plugins()
    plug_end()
  end)
end

return M
