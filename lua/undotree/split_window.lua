local split_window = {}
local if_nil = vim.F.if_nil

local _unique_winbuf = 0

local set_option = function(winid, bufnr)
  -- window options --
  vim.api.nvim_win_set_option(winid, 'number', false)
  vim.api.nvim_win_set_option(winid, 'relativenumber', false)
  vim.api.nvim_win_set_option(winid, 'winfixwidth', true)
  vim.api.nvim_win_set_option(winid, 'wrap', false)
  vim.api.nvim_win_set_option(winid, 'spell', false)
  vim.api.nvim_win_set_option(winid, 'cursorline', true)
  vim.api.nvim_win_set_option(winid, 'signcolumn', 'no')
  -- buf options --
  vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe') -- NOTE: or 'delete'
  vim.api.nvim_buf_set_option(bufnr, 'buflisted', false)
  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nowrite')
  vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
  -- vim.api.nvim_buf_set_option(bufnr, 'filetype', 'undotree')
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
end

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
  elseif type(what) == "string" then
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
