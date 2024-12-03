-- Wrapper for vim-plug with a few new features.

local M = {}

vim.g.plug_window = "vertical topleft new"
vim.g.plug_pwindow = "above 12new"

-- Functions to be called after a plugin is loaded to configure it.
local configs_by_type = {
  sync = {},
  async = {},
}

-- Call the configuration functions
local function apply_configs(configs)
  for _, config in pairs(configs) do
    config()
  end
end

local original_plug = vim.fn["plug#"]
local nix_plugins = require("nix-plugins")
local function plug(repo, options)
  local plugin_name = repo:match("^[%w-]+/([%w-_.]+)$")
  if nix_plugins[plugin_name] ~= nil then
    repo = nix_plugins[plugin_name]
    if options == nil then
      options = {}
    end
    options.as = plugin_name
  end

  if not options then
    original_plug(repo)
    return
  end

  local original_plug_options =
    vim.tbl_deep_extend("force", options, { config = nil, sync = nil })
  original_plug(repo, original_plug_options)

  local config = options.config
  if type(config) == "function" then
    if options.sync then
      table.insert(configs_by_type.sync, config)
    else
      table.insert(configs_by_type.async, config)
    end
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

local original_plug_end = vim.fn["plug#end"]
local function plug_end()
  original_plug_end()

  _G["Plug"] = nil

  -- This way code can be run after plugins are loaded, but before 'VimEnter'
  vim.api.nvim_exec_autocmds("User", { pattern = "PlugEndPost" })

  apply_configs(configs_by_type.sync)

  -- Apply the asynchronous configurations after everything else that
  -- is currently on the event loop. Now configs are applied after any
  -- files specified on the commandline are opened and after sessions are
  -- restored. This way, neovim shows me the first file "instantly" and by the
  -- time I've looked at the file and decided on my first key press, the plugin
  -- configs have already been applied.
  local function ApplyAsyncConfigs()
    apply_configs(configs_by_type.async)
  end
  vim.defer_fn(ApplyAsyncConfigs, 0)
end

-- vim-plugs enables syntax highlighting if it isn't already enabled, but I
-- don't want it since I use treesitter.  This will make vim-plug think it's
-- already on so it won't enable it.
local function run_with_faked_syntax_on(fn)
  vim.cmd.syntax("off")
  vim.g.syntax_on = true
  fn()
  vim.g.syntax_on = false
end

function M.load_plugins(plugin_definer)
  run_with_faked_syntax_on(function()
    plug_begin()
    plugin_definer()
    plug_end()
  end)
end

-- On startup, prompt the user to install any missing plugins.
vim.api.nvim_create_autocmd("User", {
  pattern = "PlugEndPost",
  callback = function()
    local plugs = vim.g.plugs or {}
    local missing_plugins = {}
    for name, info in pairs(plugs) do
      local is_installed = vim.fn.isdirectory(info.dir) ~= 0
      if not is_installed then
        missing_plugins[name] = info
      end
    end

    -- checking for empty table
    if next(missing_plugins) == nil then
      return
    end

    local missing_plugin_names = {}
    for key, _ in pairs(missing_plugins) do
      table.insert(missing_plugin_names, key)
    end

    local install_prompt = string.format(
      "The following plugins are not installed:\n%s\nWould you like to install them?",
      table.concat(missing_plugin_names, ", ")
    )
    local should_install = vim.fn.confirm(install_prompt, "yes\nno") == 1
    if should_install then
      vim.cmd(
        string.format(
          "PlugInstall --sync %s",
          table.concat(missing_plugin_names, " ")
        )
      )
    end
  end,
})

return M
