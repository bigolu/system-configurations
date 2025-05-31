-- vim:foldmethod=marker

--- ai {{{
local ai = require("mini.ai")
local spec_treesitter = ai.gen_spec.treesitter
local spec_pair = ai.gen_spec.pair

ai.setup({
  custom_textobjects = {
    d = spec_treesitter({ a = "@function.outer", i = "@function.inner" }),
    f = spec_treesitter({ a = "@call.outer", i = "@call.inner" }),
    -- TODO: @parameter.outer should include the space after the parameter delimiter
    a = spec_treesitter({ a = "@parameter.outer", i = "@parameter.inner" }),
    C = spec_treesitter({
      a = "@conditional.outer",
      i = "@conditional.inner",
    }),
    -- TODO: would be great if this worked on key/value pairs as well
    s = spec_treesitter({ a = "@assignment.lhs", i = "@assignment.rhs" }),

    -- Whole buffer
    g = function()
      local from = { line = 1, col = 1 }
      local to = {
        line = vim.fn.line("$"),
        col = math.max(vim.fn.getline("$"):len(), 1),
      }
      return { from = from, to = to }
    end,

    -- For markdown
    ["*"] = spec_pair("*", "*", { type = "greedy" }),
    ["_"] = spec_pair("_", "_", { type = "greedy" }),

    -- For lua
    ["]"] = spec_pair("[", "]", { type = "greedy" }),

    -- For Nix
    ["'"] = spec_pair("'", "'", { type = "greedy" }),
  },

  silent = true,

  -- If I still want to select next/last I can use around_{next,last} textobjects
  search_method = "cover",

  -- Number of lines within which textobject is searched
  n_lines = 100,
})

local function move_like_curly_brace(id, direction)
  local old_position = vim.api.nvim_win_get_cursor(0)
  ---@diagnostic disable-next-line: undefined-global
  MiniAi.move_cursor(direction, "a", id, {
    search_method = (direction == "left") and "cover_or_prev" or "cover_or_next",
  })
  local new_position = vim.api.nvim_win_get_cursor(0)
  local has_cursor_moved = old_position[0] ~= new_position[0] or old_position[1] ~= new_position[1]
  if has_cursor_moved then
    vim.cmd(string.format([[normal! %s]], direction == "left" and "k" or "j"))
  end
end

vim.keymap.set({ "n", "x" }, "]d", function()
  move_like_curly_brace("d", "right")
end, {
  desc = "Next function declaration",
})
vim.keymap.set({ "n", "x" }, "[d", function()
  move_like_curly_brace("d", "left")
end, {
  desc = "Last function declaration",
})
--}}}

-- operators {{{
-- Do this before mini overwrites it
local default_gx = vim
  .iter(vim.api.nvim_get_keymap("n"))
  :filter(function(k)
    return k.lhs == "gx"
  end)
  :totable()[1]
local default_gx_rhs = default_gx.rhs or default_gx.callback
vim.keymap.set("n", "U", default_gx_rhs)
vim.keymap.set("n", "<C-LeftMouse>", "U", { remap = true })

require("mini.operators").setup({
  evaluate = { prefix = "" },
  multiply = { prefix = "" },
  replace = { prefix = "" },
  exchange = { prefix = "gx" },
  sort = { prefix = "so" },
})
-- }}}

-- indentscope {{{
require("mini.indentscope").setup({
  mappings = {
    object_scope = "iI",
    object_scope_with_border = "aI",
    goto_top = "[I",
    goto_bottom = "]I",
  },
  symbol = "▏",
})

vim.g.miniindentscope_disable = false
if IsRunningInTerminal then
  vim.keymap.set("n", [[\|]], function()
    vim.g.miniindentscope_disable = not vim.g.miniindentscope_disable
    return "lh"
  end, { silent = true, expr = true, desc = "Toggle indent guide" })
end

local new_opts = {
  options = { indent_at_cursor = false },
}
local function run_without_indent_at_cursor(fn)
  local old_opts = vim.b.miniindentscope_config
  if old_opts ~= nil then
    vim.b.miniindentscope_config = vim.tbl_deep_extend("force", old_opts, new_opts)
  else
    vim.b.miniindentscope_config = new_opts
  end
  fn()
  vim.b.miniindentscope_config = old_opts
end
vim.keymap.set({ "o", "x" }, "ii", function()
  ---@diagnostic disable-next-line: undefined-global
  run_without_indent_at_cursor(MiniIndentscope.textobject)
end, {
  desc = "Inside indent of line",
})
vim.keymap.set({ "o", "x" }, "ai", function()
  run_without_indent_at_cursor(function()
    ---@diagnostic disable-next-line: undefined-global
    MiniIndentscope.textobject(true)
  end)
end, {
  desc = "Around indent of line",
})
vim.keymap.set({ "n", "x" }, "[i", function()
  run_without_indent_at_cursor(function()
    ---@diagnostic disable-next-line: undefined-global
    MiniIndentscope.move_cursor("top", false)
  end)
end, {
  desc = "Start of indent of line",
})
vim.keymap.set({ "n", "x" }, "]i", function()
  run_without_indent_at_cursor(function()
    ---@diagnostic disable-next-line: undefined-global
    MiniIndentscope.move_cursor("bottom", false)
  end)
end, {
  desc = "End of indent of line",
})

if IsRunningInTerminal then
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "python", "yaml" },
    callback = function()
      vim.b.miniindentscope_config = {
        options = {
          border = "top",
        },
      }
    end,
  })
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "man", "help" },
    callback = function()
      vim.b.miniindentscope_disable = true
      vim.b.miniindentscope_disable_permanent = true
    end,
  })
  -- TODO: I want to disable this per window, but mini only supports disabling per buffer
  vim.api.nvim_create_autocmd("BufEnter", {
    callback = function()
      if not vim.b.miniindentscope_disable_permanent then
        vim.b.miniindentscope_disable = false
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufLeave", {
    callback = function()
      vim.b.miniindentscope_disable = true
    end,
  })
end
-- }}}

-- surround {{{
local open_braces = {
  ["["] = "]",
  ["("] = ")",
  ["<"] = ">",
  ["{"] = "}",
  ["'"] = "'",
  ['"'] = '"',
}
local close_braces = {
  ["]"] = "[",
  [")"] = "(",
  [">"] = "<",
  ["}"] = "{",
}
local function get_braces(char)
  if open_braces[char] then
    return { char, open_braces[char] }
  elseif close_braces[char] then
    return { close_braces[char], char }
  else
    return nil
  end
end
local utilities = require("base.utilities")
require("mini.surround").setup({
  n_lines = 50,
  search_method = "cover",
  silent = true,
  custom_surroundings = {
    -- Search for two of the input char, d for double. Helpful for lua and Nix
    ["d"] = {
      input = function()
        local char = utilities.get_char()
        if char == nil or char == "" then
          return nil
        end
        local braces = get_braces(char)
        if braces == nil then
          return nil
        end
        return {
          string.rep(braces[1], 2) .. "().-()" .. string.rep(braces[2], 2),
        }
      end,
      output = function()
        local char = utilities.get_char()
        if char == nil or char == "" then
          return nil
        end
        local braces = get_braces(char)
        if braces == nil then
          return nil
        end
        return {
          left = string.rep(braces[1], 2),
          right = string.rep(braces[2], 2),
        }
      end,
    },
  },
})
-- }}}

-- jump {{{
require("mini.jump").setup({
  mappings = {
    repeat_jump = "",
  },
  delay = {
    highlight = 10000000,
    idle_stop = 10000000,
  },
})
-- }}}

-- bracketed {{{
require("mini.bracketed").setup({
  buffer = { suffix = "" },
  comment = { suffix = "" },
  conflict = { suffix = "" },
  diagnostic = { suffix = "" },
  file = { suffix = "" },
  indent = { suffix = "" },
  jump = { suffix = "" },
  location = { suffix = "" },
  oldfile = { suffix = "" },
  quickfix = { suffix = "" },
  treesitter = { suffix = "" },
  window = { suffix = "" },
  yank = { suffix = "" },
})

vim.keymap.set("", "[-", function()
  MiniBracketed.indent("backward", { change_type = "less" })
end)
vim.keymap.set("", "[+", function()
  MiniBracketed.indent("backward", { change_type = "more" })
end)
vim.keymap.set("", "]-", function()
  MiniBracketed.indent("forward", { change_type = "less" })
end)
vim.keymap.set("", "]+", function()
  MiniBracketed.indent("forward", { change_type = "more" })
end)

local make_nextprev_indent = function(advance_to_nonblank, increment)
  return function(cur_lnum)
    -- Correctly process initial blank line
    cur_lnum = advance_to_nonblank(cur_lnum)
    local init_indent = vim.fn.indent(cur_lnum)
    local visited_different_indent = false

    local new_lnum, new_indent = cur_lnum, init_indent
    -- Check with `new_lnum > 0` because `nextnonblank()` returns -1 if line is
    -- outside of line range
    while new_lnum > 0 do
      new_indent = vim.fn.indent(new_lnum)
      visited_different_indent = visited_different_indent or new_indent ~= init_indent
      if new_indent == init_indent and visited_different_indent then
        return new_lnum
      end
      new_lnum = advance_to_nonblank(new_lnum + increment)
    end
  end
end
local indent_same = function(direction)
  local iterator = {
    next = make_nextprev_indent(vim.fn.nextnonblank, 1),
    prev = make_nextprev_indent(vim.fn.prevnonblank, -1),
    state = vim.fn.line("."),
  }
  local res_line_num = MiniBracketed.advance(iterator, direction, { wrap = false })
  if res_line_num == nil then
    return
  end

  -- Navigate to the first non-blank character of the target line
  vim.api.nvim_win_set_cursor(0, { res_line_num, 0 })
  vim.cmd("normal! zv^")
end
vim.keymap.set("", "[=", function()
  indent_same("backward")
end)
vim.keymap.set("", "]=", function()
  indent_same("forward")
end)
-- }}}

if IsRunningInTerminal then
  require("mini.misc").setup_restore_cursor({ center = false })
  require("mini.pairs").setup()
  require("mini.snippets").setup({
    mappings = {
      expand = "",
      jump_next = "<C-l>",
      jump_prev = "<C-h>",
      stop = "<Esc>",
    },
  })

  -- misc {{{
  local misc = require("mini.misc")
  vim.keymap.set("n", "<C-m>", function()
    if not IsMaximized then
      vim.api.nvim_create_autocmd("WinEnter", {
        once = true,
        callback = function()
          vim.o.winhighlight = "NormalFloat:Normal"
        end,
      })
      misc.zoom(0, {
        anchor = "SW",
        row = 1,
        col = 1,
        height = vim.o.lines - 1,
      })
      IsMaximized = true
    else
      IsMaximized = false

      -- Set cursor in original window to that of the maximized window.
      -- TODO: I should upstream this
      local maximized_window_cursor_position = vim.api.nvim_win_get_cursor(0)
      vim.api.nvim_create_autocmd("WinEnter", {
        once = true,
        callback = function()
          vim.api.nvim_win_set_cursor(0, maximized_window_cursor_position)
        end,
      })

      misc.zoom()
    end
  end, {
    desc = "Toggle maximize window [zoom]",
  })
  -- }}}

  -- cursorword {{{
  require("mini.cursorword").setup()

  local cursorword_highlight_name = "MiniCursorword"
  local function disable_cursorword()
    vim.opt_local.winhighlight:append(cursorword_highlight_name .. ":Clear")
  end
  local function enable_cursorword()
    vim.opt_local.winhighlight:remove(cursorword_highlight_name)
  end

  -- Don't highlight in inactive windows
  vim.api.nvim_create_autocmd("WinLeave", {
    callback = function(_)
      disable_cursorword()
    end,
  })
  vim.api.nvim_create_autocmd("WinEnter", {
    callback = function(_)
      enable_cursorword()
    end,
  })
  -- }}}

  -- completion {{{
  local window_info = {
    height = math.floor(vim.o.lines * 0.35),
    width = math.min(80, math.floor(vim.o.columns * 0.65)),
    border = "rounded",
  }

  require("mini.completion").setup({
    mappings = { force_fallback = "" },

    lsp_completion = {
      source_func = "omnifunc",
      auto_setup = false,
    },

    window = {
      info = window_info,
      signature = window_info,
    },
  })

  local keys = {
    ["ctrl-y"] = vim.keycode("<C-y>"),
    ["ctrl-y_cr"] = vim.keycode("<C-y><CR>"),
  }
  vim.keymap.set("i", "<CR>", function()
    if vim.fn.pumvisible() ~= 0 then
      -- If popup is visible, confirm selected item or add new line otherwise
      local item_selected = vim.fn.complete_info()["selected"] ~= -1
      return item_selected and keys["ctrl-y"] or keys["ctrl-y_cr"]
    else
      return require("mini.pairs").cr()
    end
  end, { expr = true })

  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      assert(client ~= nil)
      local methods = vim.lsp.protocol.Methods
      if client:supports_method(methods.textDocument_completion) then
        vim.bo[args.buf].omnifunc = "v:lua.MiniCompletion.completefunc_lsp"
      end
    end,
  })

  local function is_completion_menu_open()
    return tonumber(vim.fn.pumvisible()) ~= 0
  end

  vim.keymap.set("i", "<Tab>", function()
    if is_completion_menu_open() then
      -- Select next entry
      return "<C-n>"
    else
      return "<Tab>"
    end
  end, { expr = true })

  vim.keymap.set("i", "<S-Tab>", function()
    if is_completion_menu_open() then
      -- Select previous entry
      return "<C-p>"
    else
      return "<S-Tab>"
    end
  end, { expr = true })
  -- }}}

  -- diff {{{
  -- Ghostty extends the background color to the edge of the terminal window so
  -- instead of using a "left 1/4 block" I use a "right 3/4 block" and reverse
  -- the highlight. I also add a "full block" afterwards since signs are given
  -- two cells.
  local sign = "🮋█"

  require("mini.diff").setup({
    view = {
      style = "sign",
      signs = { add = sign, change = sign, delete = sign },
      priority = 1,
    },

    mappings = {
      apply = "",
      reset = "",
      textobject = "",
      goto_first = "",
      goto_last = "",
      goto_prev = "[c",
      goto_next = "]c",
    },

    options = { wrap_goto = true },
  })
  -- }}}

  -- pick {{{
  local mini_pick = require("mini.pick")

  mini_pick.setup({
    mappings = {
      move_down = "<Tab>",
      move_up = "<S-Tab>",
      toggle_preview = "<C-p>",
      scroll_down = "<C-j>",
      scroll_left = "<C-h>",
      scroll_right = "<C-l>",
      scroll_up = "<C-k>",
      toggle_info = "",
    },

    window = {
      config = function()
        return { width = vim.o.columns }
      end,
    },
  })

  vim.keymap.set({ "n" }, "<leader>f", function()
    vim.cmd.Pick("files")
  end)
  vim.keymap.set({ "n" }, "<leader>g", function()
    vim.cmd.Pick("grep_live")
  end)
  vim.keymap.set({ "n" }, "<leader><leader>", function()
    vim.cmd.Pick("resume")
  end)

  ---@diagnostic disable-next-line: duplicate-set-field
  vim.ui.select = function(items, opts, on_choice)
    return mini_pick.ui_select(items, opts, on_choice, {
      window = {
        config = {
          width = vim.o.columns,
          height = math.min(math.floor(vim.o.lines * 0.50), #items),
        },
      },
    })
  end
  -- }}}

  -- notify {{{
  local notify = require("mini.notify")

  notify.setup({
    content = {
      format = function(data)
        return data.msg
      end,
    },
    window = {
      winblend = 0,
      config = function()
        return {
          title = "",
          anchor = "SE",
          col = vim.o.columns,
          -- The subtraction is to clear the statusline
          row = vim.o.lines - 1,
          border = { "", "", "", "🮇", "", "", "", " " },
        }
      end,
    },
  })

  vim.notify = notify.make_notify()
  vim.keymap.set({ "n" }, "<leader>h", notify.show_history)
  -- }}}
end
