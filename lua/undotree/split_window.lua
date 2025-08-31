local floor = math.floor

local _unique_winbuf = 0

---@param winid integer
---@param bufnr integer
local function set_option(winid, bufnr)
  local opts_buf_set, opts_win_set = { buf = bufnr }, { win = winid }

  -- window options --
  local window_opts = {
    number = false,
    relativenumber = false,
    winfixwidth = true,
    wrap = false,
    spell = false,
    cursorline = true,
    signcolumn = "no",
  }

  for option, value in pairs(window_opts) do
    vim.api.nvim_set_option_value(option, value, opts_win_set)
  end

  -- buf options --
  local buffer_opts = {
    bufhidden = "wipe", -- NOTE: or 'delete'
    buflisted = false,
    buftype = "nowrite",
    swapfile = false,
    -- filetype = "undotree",
    modifiable = false,
  }

  for option, value in pairs(buffer_opts) do
    vim.api.nvim_set_option_value(option, value, opts_buf_set)
  end
end

---@class UndoTreeSplitWindow
local split_window = {}

---@param self UndoTreeSplitWindow
---@param what string|integer
---@param opts? UndoWinTree.Opts
---@return integer winid
---@return integer prev_winid
function split_window:create(what, opts)
  opts = opts or {}

  local size, c_win_command = 0, { "silent keepalt" }

  if opts.position == "bottom" then
    table.insert(c_win_command, "botright")
    size = opts.size or floor(vim.o.lines * 0.30)
  elseif opts.position == "left_bottom" then
    size = opts.size or floor(vim.o.lines * 0.35)
  elseif opts.position == "right" then
    table.insert(c_win_command, "botright vertical")
    size = opts.size or floor(vim.o.columns * 0.25)
  else -- DEFAULT: opts.postion == "left"
    table.insert(c_win_command, "topleft vertical")
    size = opts.size or floor(vim.o.columns * 0.25)
  end
  table.insert(c_win_command, size)

  local what_t = type(what)

  if what_t == "number" then
    table.insert(c_win_command, "split")
  elseif what_t == "string" then
    if what ~= "" then
      table.insert(c_win_command, "new " .. what)
    else
      table.insert(c_win_command, "new [Scratch-" .. _unique_winbuf .. "]")
      _unique_winbuf = _unique_winbuf + 1
    end
  end

  local prev_winid = vim.fn.win_getid()
  vim.cmd(table.concat(c_win_command, " "))
  local winid = vim.fn.win_getid()

  if what_t == "number" then
    vim.api.nvim_win_set_buf(winid, what)
  end

  if not opts.enter then
    vim.cmd("noautocmd lua vim.api.nvim_set_current_win(" .. prev_winid .. ")")
  end
  set_option(winid, vim.fn.winbufnr(winid))

  return winid, prev_winid
end

return split_window

-- vim:ts=2:sts=2:sw=2:et:ai:si:sta:
