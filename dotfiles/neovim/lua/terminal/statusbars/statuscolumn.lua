local function is_virtual_line()
  return vim.v.virtnum < 0
end

local function is_wrapped_line()
  return vim.v.virtnum > 0
end

-- Fold column calculation was taken from the following files in the plugin
-- statuscol.nvim:
-- https://github.com/luukvbaal/statuscol.nvim/blob/98d02fc90ebd7c4674ec935074d1d09443d49318/lua/statuscol/ffidef.lua
-- https://github.com/luukvbaal/statuscol.nvim/blob/98d02fc90ebd7c4674ec935074d1d09443d49318/lua/statuscol/builtin.lua
local ffi = require("ffi")
-- I moved this call to `cdef` outside the fold function because I was getting
-- the error "table overflow" a few seconds into using neovim. Plus, not calling
-- this during the fold function is faster.
ffi.cdef([[
  int next_namespace_id;
  uint64_t display_tick;
  typedef struct {} Error;
  typedef struct {} win_T;
  typedef struct {
    int start;  // line number where deepest fold starts
    int level;  // fold level, when zero other fields are N/A
    int llevel; // lowest level that starts in v:lnum
    int lines;  // number of lines from v:lnum to end of closed fold
  } foldinfo_T;
  foldinfo_T fold_info(win_T* wp, int lnum);
  win_T *find_window_by_handle(int Window, Error *err);
  int compute_foldcolumn(win_T *wp, int col);
  int win_col_off(win_T *wp);
]])
-- This should be much simpler when this issue is resolved:
-- https://github.com/neovim/neovim/issues/21740
local function get_fold_sign()
  local wp =
    ffi.C.find_window_by_handle(vim.g.statusline_winid, ffi.new("Error"))
  local foldinfo = ffi.C.fold_info(wp, vim.v.lnum)
  local string = "%#FoldColumn#"
  local level = foldinfo.level

  if is_virtual_line() or is_wrapped_line() or level == 0 then
    return "  "
  end

  if foldinfo.start == vim.v.lnum then
    local closed = foldinfo.lines > 0
    if closed then
      string = string .. ""
    else
      string = string .. ""
    end
  else
    string = string .. " "
  end
  string = string .. " "

  return string
end

function StatusColumn()
  local line_number = "%l"
  local git_sign = "%s"
  local fold_sign = get_fold_sign()

  return line_number .. git_sign .. fold_sign
end

vim.o.statuscolumn = "%!v:lua.StatusColumn()"
vim.o.signcolumn = "yes:1"
