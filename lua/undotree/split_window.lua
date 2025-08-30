local if_nil = vim.F.if_nil
local fmt = string.format

local floor = math.floor

local _unique_winbuf = 0

local function set_option(winid, bufnr)
  local buf_opt, win_opt = { buf = bufnr }, { win = winid }

  -- window options --
  vim.api.nvim_set_option_value("number", false, win_opt)
  vim.api.nvim_set_option_value("relativenumber", false, win_opt)
  vim.api.nvim_set_option_value("winfixwidth", true, win_opt)
  vim.api.nvim_set_option_value("wrap", false, win_opt)
  vim.api.nvim_set_option_value("spell", false, win_opt)
  vim.api.nvim_set_option_value("cursorline", true, win_opt)
  vim.api.nvim_set_option_value("signcolumn", "no", win_opt)

  -- buf options --
  vim.api.nvim_set_option_value("bufhidden", "wipe", buf_opt) -- NOTE: or 'delete'
  vim.api.nvim_set_option_value("buflisted", false, buf_opt)
  vim.api.nvim_set_option_value("buftype", "nowrite", buf_opt)
  vim.api.nvim_set_option_value("swapfile", false, buf_opt)
  -- vim.api.nvim_set_option_value('filetype', 'undotree', buf_opt)
  vim.api.nvim_set_option_value("modifiable", false, buf_opt)
end

---@class UndoTreeSplitWindow
local split_window = {}

function split_window:create(what, opts)
  opts = opts or {}
  local c_win_cmd = { "silent keepalt" }

  local switch_case = {
    bottom = { "botright", floor(vim.o.lines * 0.30) },
    left_bottom = { "", floor(vim.o.lines * 0.35) },
    right = { "botright vertical", floor(vim.o.columns * 0.25) },
    left = { "topleft vertical", floor(vim.o.columns * 0.25) },
  }

  if not (opts.position ~= nil and vim.tbl_contains(vim.tbl_keys(switch_case), opts.position)) then
    opts.position = "left"
  end

  local case = switch_case[opts.position]
  if case[1] ~= "" then
    table.insert(c_win_cmd, case[1])
  end
  table.insert(c_win_cmd, if_nil(opts.size, case[2]))

  switch_case = {
    number = "split",
    string = (what ~= "" and fmt("new %s", what) or fmt("new [Scratch-%s]", _unique_winbuf)),
  }
  case = switch_case[type(what)] or ""

  if case ~= "" then
    table.insert(c_win_cmd, case)
  end
  if what == "" then
    _unique_winbuf = _unique_winbuf + 1
  end

  local prev_winid = vim.fn.win_getid()

  vim.cmd(table.concat(c_win_cmd, " "))
  local winid = vim.fn.win_getid()

  if type(what) == "number" then
    vim.api.nvim_win_set_buf(winid, what)
  end

  if not opts.enter then
    vim.cmd(fmt("noautocmd lua vim.api.nvim_set_current_win(%s)", prev_winid))
  end
  set_option(winid, vim.fn.winbufnr(winid))

  return winid, prev_winid
end

return split_window

-- vim:ts=2:sts=2:sw=2:et:ai:si:sta:
