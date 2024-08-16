local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Utilities
local function table_concat(t1, t2)
  for i = 1, #t2 do
    t1[#t1 + 1] = t2[i]
  end
  return t1
end
local function merge_to_left(t1, t2)
  for k, v in pairs(t2) do
    if (type(v) == "table") and (type(t1[k] or false) == "table") then
      merge_to_left(t1[k], t2[k])
    else
      t1[k] = v
    end
  end
  return t1
end
local is_mac = string.find(wezterm.target_triple, "darwin")
local CustomEvent = {
  ThemeChanged = "theme-changed",
  ThemeToggleRequested = "theme-toggled",
  SystemAppearanceChanged = "system-appearance-changed",
}
local state_directory = os.getenv("XDG_STATE_HOME")
  or (os.getenv("HOME") .. "/.local/state")
local nvim_wezterm_runtime_directory = state_directory .. "/nvim-wezterm"

-- general
config.window_close_confirmation = "NeverPrompt"
config.audible_bell = "Disabled"
config.default_cursor_style = "BlinkingBar"
config.bold_brightens_ansi_colors = false
config.disable_default_key_bindings = true
-- I had an issue where WezTerm would sometimes freeze when I input a key and I
-- would have to input another key to fix it, but setting this to false seems to
-- fix that. Solution came from here:
-- https://www.reddit.com/r/commandline/comments/1621suy/help_issue_with_wezterm_and_vim_key_repeat/
config.use_ime = false
config.enable_kitty_keyboard = true
config.enable_kitty_graphics = true
config.automatically_reload_config = false
config.window_padding = {
  left = "0.5cell",
  right = "0.5cell",
  top = "0.5cell",
  bottom = "0.5cell",
}
config.term = "wezterm"

-- font
-- Per the recommendation in the mini.icons readme
config.allow_square_glyphs_to_overflow_width = "Always"
local function font_with_icon_fallbacks(font)
  return wezterm.font_with_fallback({ font, "SymbolsNerdFontMono" })
end
local handwriting_font = "Monaspace Radon"
-- For Linux, I'd like to put 'monospace' here so Wezterm can use the monospace
-- font that I set for my system, but Flatpak apps can't access my font
-- configuration file from their sandbox so for now I'll hardcode a font.
--
-- issue: https://github.com/flatpak/flatpak/issues/1563
config.font = font_with_icon_fallbacks("Hack")
config.font_rules = {
  {
    intensity = "Normal",
    italic = true,
    font = font_with_icon_fallbacks(handwriting_font),
  },
  {
    intensity = "Bold",
    italic = true,
    font = font_with_icon_fallbacks({
      family = handwriting_font,
      weight = "Bold",
    }),
  },
}
if is_mac then
  config.font_size = 13.5
  config.line_height = 1.5
  config.underline_position = "400%"
else
  config.font_size = 11.3

  -- TODO: I want this to be the same as macOS, but the font gets cut off when I
  -- try.
  config.line_height = 1.25

  -- TODO: I want this to be the same as macOS, but the underline doesn't show
  -- up when I try.
  config.underline_position = "200%"
end
config.underline_thickness = "150%"

-- SYNC: terminal-color-palettes
local my_colors_per_color_scheme = {
  ["Biggs Nord"] = {
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
  },

  ["Biggs Light Owl"] = {
    [0] = "#ffffff",
    [1] = "#cf222e",
    [2] = "#116329",
    [3] = "#e9873a",
    [4] = "#0969da",
    [5] = "#8250df",
    [6] = "#1b7c83",
    [7] = "#1f2328",
    [8] = "#808080",
    [9] = "#a40e26",
    [10] = "#1a7f37",
    [11] = "#c96765",
    [12] = "#218bff",
    [13] = "#a475f9",
    [14] = "#3192aa",
    [15] = "#808080",
  },
}

local function create_color_schemes(colors_per_color_scheme)
  local color_schemes = {}

  for color_scheme_name, colors in pairs(colors_per_color_scheme) do
    -- Make a skeleton for the color scheme that we'll fill in below
    local color_scheme = {
      ["ansi"] = {},
      ["brights"] = {},
    }

    for index, color in pairs(colors) do
      if index == 0 then
        color_scheme["background"] = color
        color_scheme["cursor_fg"] = color_scheme["background"]
        color_scheme["selection_fg"] = color
      elseif index == 7 then
        color_scheme["foreground"] = color
        color_scheme["selection_bg"] = color
        color_scheme["scrollbar_thumb"] = color
        color_scheme["cursor_border"] = color
        -- TODO: For `cursor_border` to work, `cursor_bg` needs to be set to the
        -- same color
        -- issue: https://github.com/wez/wezterm/issues/1494
        color_scheme["cursor_bg"] = color
      elseif index == 8 then
        color_scheme["split"] = color
      end

      if index >= 0 and index <= 7 then
        color_scheme["ansi"][index + 1] = color
      elseif index >= 8 and index <= 15 then
        color_scheme["brights"][index - 7] = color
      end
    end

    color_schemes[color_scheme_name] = color_scheme
  end

  return color_schemes
end
config.color_schemes = create_color_schemes(my_colors_per_color_scheme)

local function create_theme_config(color_scheme_name)
  local color_scheme = config.color_schemes[color_scheme_name]
  local background = color_scheme.background
  -- This way I can hide the tab bar
  local foreground = background
  return {
    color_scheme = color_scheme_name,
    window_frame = {
      active_titlebar_bg = background,
      inactive_titlebar_bg = background,
    },
    colors = {
      tab_bar = {
        background = background,
        active_tab = {
          bg_color = background,
          fg_color = foreground,
        },
        inactive_tab = {
          bg_color = background,
          fg_color = foreground,
        },
        active_tab_hover = {
          bg_color = background,
          fg_color = foreground,
        },
        inactive_tab_hover = {
          bg_color = background,
          fg_color = foreground,
        },
      },
    },
  }
end
local Theme = {
  Dark = {
    as_string = "dark",
    config = create_theme_config("Biggs Nord"),
  },
  Light = {
    as_string = "light",
    config = create_theme_config("Biggs Light Owl"),
  },
}
Theme.for_system_appearance = function(appearance)
  if appearance:find("Dark") then
    return Theme.Dark
  else
    return Theme.Light
  end
end
Theme.from_window = function(window)
  local overrides = window:get_config_overrides() or {}
  if Theme.Light.config.color_scheme == overrides.color_scheme then
    return Theme.Light
  else
    return Theme.Dark
  end
end
Theme.inverse = function(theme)
  if theme == Theme.Dark then
    return Theme.Light
  else
    return Theme.Dark
  end
end

local function set_theme(window, theme)
  local overrides = window:get_config_overrides() or {}
  merge_to_left(overrides, theme.config)
  window:set_config_overrides(overrides)
  wezterm.emit(CustomEvent.ThemeChanged, theme)
end

-- Change theme automatically when the system theme changes
--
-- There is no event for when the system appearance changes. Instead, when the
-- appearance changes, the 'window-config-reloaded' event is fired. To get
-- around this, I keep track of the current system appearance fire my own event
-- when I detect a change.
local current_system_appearance = nil
wezterm.on("window-config-reloaded", function(window)
  local new_system_appearance = wezterm.gui.get_appearance()
  if current_system_appearance ~= new_system_appearance then
    current_system_appearance = new_system_appearance
    wezterm.emit(
      CustomEvent.SystemAppearanceChanged,
      window,
      current_system_appearance
    )
  end
end)
wezterm.on(CustomEvent.SystemAppearanceChanged, function(window, new_appearance)
  set_theme(window, Theme.for_system_appearance(new_appearance))
end)

-- Toggle the current theme. This event is fired from a keybinding
wezterm.on(CustomEvent.ThemeToggleRequested, function(window)
  set_theme(window, Theme.inverse(Theme.from_window(window)))
end)

-- Sync theme with neovim
local function fire_theme_event_in_neovim(theme)
  local pipe_directory = nvim_wezterm_runtime_directory .. "/pipes"
  local event_name = theme == Theme.Dark and "ColorSchemeDark"
    or "ColorSchemeLight"
  if os.execute(string.format([[test -d %s]], pipe_directory)) then
    -- I'm executing the neovim remote commands in the background so this way if
    -- a neovim instance is blocked (e.g. A 'Press enter to continue prompt' is
    -- being shown like when you execute `:mess`), preventing it from handling
    -- the remote message immediately, wezterm will not be blocked.
    os.execute(
      string.format(
        [=[find '%s' \( -type s -o -type p \) -exec sh -c '"%s" --server {} --remote-expr '"'"'v:lua.vim.api.nvim_exec_autocmds("User", {"pattern": "%s"})'"'"' &' \;]=],
        pipe_directory,
        nvim_wezterm_runtime_directory .. "/nvim",
        event_name
      )
    )
  end
end
local function set_theme_in_state_file(theme)
  local theme_file = nvim_wezterm_runtime_directory .. "/current-theme.txt"
  os.execute(
    string.format(
      [[mkdir -p '%s' && echo '%s' > '%s']],
      nvim_wezterm_runtime_directory,
      theme.as_string,
      theme_file
    )
  )
end
---@diagnostic disable-next-line: unused-local
wezterm.on(CustomEvent.ThemeChanged, function(theme)
  fire_theme_event_in_neovim(theme)
  -- This way neovim can get the current wezterm theme on startup
  set_theme_in_state_file(theme)
end)

-- Decorations
local decorations = "INTEGRATED_BUTTONS|RESIZE"
if is_mac then
  -- disable this since it may affect performance:
  -- https://github.com/wez/wezterm/issues/2669#issuecomment-1411507194
  decorations = decorations .. "|MACOS_FORCE_DISABLE_SHADOW"
end
config.window_decorations = decorations
config.show_new_tab_button_in_tab_bar = false
config.show_tab_index_in_tab_bar = false
-- TODO: I don't know why I need this
config.colors = {}

local keybinds = {
  {
    key = "c",
    mods = "ALT",
    action = wezterm.action.EmitEvent(CustomEvent.ThemeToggleRequested),
  },
  {
    key = "v",
    mods = "SUPER",
    action = wezterm.action.PasteFrom("Clipboard"),
  },

  {
    key = "m",
    mods = "CTRL",
    action = wezterm.action.SendKey({
      key = "F6",
    }),
  },
  {
    key = "[",
    mods = "CTRL",
    action = wezterm.action.SendKey({
      key = "F7",
    }),
  },
  {
    key = "]",
    mods = "CTRL",
    action = wezterm.action.SendKey({
      key = "F8",
    }),
  },
  {
    key = "i",
    mods = "CTRL",
    action = wezterm.action.SendKey({
      key = "F9",
    }),
  },
  {
    key = "q",
    mods = "CMD",
    action = wezterm.action.CloseCurrentTab({ confirm = false }),
  },
  {
    key = "r",
    mods = "ALT|SHIFT",
    action = wezterm.action.ReloadConfiguration,
  },
}

local function generate_neovim_tab_navigation_keybinds()
  local result = {}
  for tab_number = 1, 9 do
    local tab_number_string = tostring(tab_number)

    local keybind = {
      key = tab_number_string,
      mods = "CTRL",
      action = wezterm.action.Multiple({
        wezterm.action.SendKey({ key = "Space" }),
        wezterm.action.SendKey({ key = tab_number_string }),
      }),
    }

    table.insert(result, keybind)
  end

  return result
end

config.keys = table_concat(keybinds, generate_neovim_tab_navigation_keybinds())

return config
