local if_nil = vim.F.if_nil

local _unique_winbuf = 0

local function set_option(winid, bufnr)
  -- window options --
  vim.api.nvim_set_option_value('number', false, { win = winid })
  vim.api.nvim_set_option_value('relativenumber', false, { win = winid })
  vim.api.nvim_set_option_value('winfixwidth', true, { win = winid })
  vim.api.nvim_set_option_value('wrap', false, { win = winid })
  vim.api.nvim_set_option_value('spell', false, { win = winid })
  vim.api.nvim_set_option_value('cursorline', true, { win = winid })
  vim.api.nvim_set_option_value('signcolumn', 'no', { win = winid })
  -- buf options --
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr }) -- NOTE: or 'delete'
  vim.api.nvim_set_option_value('buflisted', false, { buf = bufnr })
  vim.api.nvim_set_option_value('buftype', 'nowrite', { buf = bufnr })
  vim.api.nvim_set_option_value('swapfile', false, { buf = bufnr })
  -- vim.api.nvim_set_option_value('filetype', 'undotree', { buf = bufnr })
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
end

---@class UndoTreeSplitWindow
local split_window = {}

function split_window:create(what, opts)
  opts = opts or {}
  local size = 0
  local c_win_command = { "silent keepalt" }

  if opts.position == "bottom" then
    table.insert(c_win_command, "botright")
    size = if_nil(opts.size, math.floor(vim.o.lines * 0.30))
  elseif opts.position == "left_bottom" then
    size = if_nil(opts.size, math.floor(vim.o.lines * 0.35))
  elseif opts.position == "right" then
    table.insert(c_win_command, "botright vertical")
    size = if_nil(opts.size, math.floor(vim.o.columns * 0.25))
  else -- DEFAULT: opts.postion == "left"
    table.insert(c_win_command, "topleft vertical")
    size = if_nil(opts.size, math.floor(vim.o.columns * 0.25))
  end
  table.insert(c_win_command, size)

  if type(what) == "number" then
    table.insert(c_win_command, "split")
  elseif type(what) == "string" and what ~= "" then
    table.insert(c_win_command, "new " .. what)
  elseif type(what) == "string" then
    table.insert(c_win_command, "new [Scratch-" .. _unique_winbuf .. "]")
    _unique_winbuf = _unique_winbuf + 1
  end

  local prev_winid = vim.fn.win_getid()
  vim.cmd(table.concat(c_win_command, " "))
  local winid = vim.fn.win_getid()

  if type(what) == "number" then
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