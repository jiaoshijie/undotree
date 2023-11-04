local conf = require('undotree.config')
local undotree = require('undotree.undotree')
local Diff = require("undotree.diff")
local split_win = require("undotree.split_window")
local action = require("undotree.action")

local popup = require('plenary.popup')

local if_nil = vim.F.if_nil

local Collector = {}
Collector.__index = Collector

local default_opt = {
  float_diff = true, -- set this `true` will disable layout option
  ignore_filetype = { 'undotree', 'undotreeDiff', 'qf', 'TelescopePrompt', 'spectre_panel', 'tsplayground' },
  undotree_info = undotree:new(),
  layout = "left_bottom", -- "left_bottom", "left_left_bottom"
  position = "left", -- "right", "bottom"
  diff_previewer = Diff:new(),
  window = {
    winblend = 30,
    -- TODO: maybe change it to a suitable number
    height = 0,
    width = 0,
  },
  keymaps = {
    ['j'] = "move_next",
    ['k'] = "move_prev",
    ['gj'] = "move2parent",
    ['J'] = "move_change_next",
    ['K'] = "move_change_prev",
    ['<cr>'] = "action_enter",
    ['p'] = "enter_diffbuf",
    ['q'] = "quit",
  },
}

local find_star = function(lnum)
  local line = vim.fn.getline(lnum)
  if line and line ~= "" then
    local col = 1
    while col <= #line do
      if string.sub(line, col, col) == "*" then
        return true, col - 1 -- found, position
      end
      col = col + 1
    end
  end
  return false, 0
end

local buf_delete = function(bufnr)
  if bufnr == nil then
    return
  end

  -- Suppress the buffer deleted message for those with &report<2
  local start_report = vim.o.report
  if start_report < 2 then
    vim.o.report = 2
  end

  if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end

  if start_report < 2 then
    vim.o.report = start_report
  end
end

local win_delete = function(win_id, force, bdelete)
  if win_id == nil or not vim.api.nvim_win_is_valid(win_id) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(win_id)
  if bdelete then
    buf_delete(bufnr)
  end

  if not vim.api.nvim_win_is_valid(win_id) then
    return
  end

  vim.api.nvim_win_close(win_id, force)
end


function Collector:new(opts)
  opts = opts or {}
  local obj = setmetatable({
    float_diff = if_nil(opts.float_diff, default_opt.float_diff),
    ignore_filetype = if_nil(opts.ignore_filetype, default_opt.ignore_filetype),
    undotree_info = undotree:new(),
    diff_previewer = Diff:new(),
    layout = if_nil(opts.layout, default_opt.layout),
    position = if_nil(opts.position, default_opt.position),
  }, self)

  obj.window = vim.deepcopy(default_opt.window)
  if opts.window then
    for k, v in pairs(opts.window) do
      obj.window[k] = v
    end
  end

  obj.keymaps = vim.deepcopy(default_opt.keymaps)
  if opts.keymaps then
    for k, v in pairs(opts.keymaps) do
      obj.keymaps[k] = v
    end
  end

  return obj
end

function Collector:run()
  if conf.contains(self.ignore_filetype, vim.bo.filetype) then
    return
  end

  self.src_winid = vim.fn.win_getid()
  self.src_bufnr = vim.fn.bufnr()

  local line_count = vim.o.lines - vim.o.cmdheight
  if vim.o.laststatus ~= 0 then
    line_count = line_count - 1
  end
  if vim.fn.exists('+winbar') ~= 0 and vim.o.winbar ~= "" then
    line_count = line_count - 1
  end

  local win_opts = self:get_window_option(vim.o.columns, line_count)

  local u_win, _ = split_win:create("", win_opts.undotree_opts)

  self.undotree_win = u_win
  self.undotree_bufnr = vim.api.nvim_win_get_buf(u_win)

  vim.api.nvim_buf_set_option(self.undotree_bufnr, "filetype", "undotree")

  if self.float_diff then
    -- NOTE: _ is diff_opts
    self.diff_win_opts = win_opts.diff_opts
  else
    self.diff_win, _ = split_win:create("", win_opts.diff_opts)
    self.diff_bufnr = vim.api.nvim_win_get_buf(self.diff_win)
    vim.api.nvim_buf_set_option(self.diff_bufnr, "filetype", "undotreeDiff")
  end

  self:reflash_undotree(true)

  -- Always enter to undotree window
  vim.cmd("noautocmd lua vim.api.nvim_set_current_win(" .. self.undotree_win .. ")")
  self:set_marks(self.undotree_info.seq_cur)

  for k, v in pairs(self.keymaps) do
    vim.keymap.set('n', k, function()
      action[v](self)
    end, { noremap = true, silent = true, buffer = self.undotree_bufnr })
  end

  local lnum = self.undotree_info.seq2line[self.undotree_info.seq_cur]
  local _, col = find_star(lnum)
  self:set_selection({ lnum, col })

  local group = vim.api.nvim_create_augroup("Undotree_collector", { clear = true })
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    buffer = self.undotree_bufnr,
    group = group,
    callback = function()
      win_delete(self.diff_win, true, true)
      win_delete(self.diff_border, true, true)
      self.src_bufnr = nil
    end,
  })
end

function Collector:create_popup_win(bufnr, popup_opts)
  local what = bufnr or ""
  local win, opts = popup.create(what, popup_opts)
  vim.api.nvim_win_set_option(win, "winblend", self.window.winblend)
  vim.api.nvim_win_set_option(win, "wrap", false)
  local border_win = opts and opts.border and opts.border.win_id
  if border_win then
    vim.api.nvim_win_set_option(border_win, "winblend", self.window.winblend)
  end
  return win, opts, border_win
end

function Collector:get_window_option(max_columns, max_lines)
  local min_columns, min_lines = math.floor(max_columns * 0.25), math.floor(max_lines * 0.30)
  local opts = { undotree_opts = {}, diff_opts = {} }

  self.window.width = if_nil(self.window.width, 0)
  local width = math.max(self.window.width, min_columns)
  opts.undotree_opts.size = math.min(width, max_columns)
  opts.undotree_opts.position = self.position
  if not self.float_diff and self.layout == "left_left_bottom" then
    opts.undotree_opts.enter = true
  else
    opts.undotree_opts.enter = false
  end

  if self.float_diff then
    opts.diff_opts.border = true
    opts.diff_opts.enter = false
    local height = math.floor(max_lines * 0.8)
    opts.diff_opts.line = math.floor((max_lines - height) / 2)
    opts.diff_opts.height = height
    opts.diff_opts.minheight = height
    opts.diff_opts.borderchars = if_nil(self.window.borderchars, { "─", "│", "─", "│", "╭", "╮", "╯", "╰" })
    opts.diff_opts.title = "Diff Previewer"
    if self.position == "right" then
      opts.diff_opts.col = opts.undotree_opts.size - 15
      opts.diff_opts.width = math.floor((max_columns - (opts.undotree_opts.size + 10)) * 0.8)
    else
      opts.diff_opts.col = opts.undotree_opts.size + 10
      opts.diff_opts.width = math.floor((max_columns - opts.diff_opts.col) * 0.8)
    end
    -- borderhighlight, highlight, titlehighlight
  else
    self.window.height = if_nil(self.window.height, 0)
    local height = math.max(self.window.height, min_lines)
    opts.diff_opts.size = math.min(height, max_lines)
    opts.diff_opts.enter = false
    if self.layout == "left_bottom" then
      opts.diff_opts.position = "bottom"
    else -- self.layout == "left_left_bottom"
      opts.diff_opts.position = "left_bottom"
    end
  end

  return opts
end

function Collector:reflash_undotree(always_flash)
  vim.cmd("noautocmd lua vim.api.nvim_set_current_win(" .. self.src_winid .. ")")

  local reflash = self.undotree_info:gen_graph_tree()
  if always_flash == true or reflash == true then
    vim.api.nvim_buf_set_option(self.undotree_bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(self.undotree_bufnr, 0, -1, false, self.undotree_info.char_graph)
    vim.api.nvim_buf_set_option(self.undotree_bufnr, "modifiable", false)
  end
end

function Collector:move_selection(change, not_reflash)
  local lnum = vim.fn.line('.') + change
  local col = 0
  local found = false
  while lnum >= 1 and lnum <= vim.fn.line('$') do
    found, col = find_star(lnum)
    if found then
      self:set_selection({ lnum, col }, not_reflash)
      return
    end
    lnum = lnum + change
  end
end

function Collector:set_selection(pos, not_reflash)
  vim.api.nvim_win_set_cursor(self.undotree_win, pos)
  if not not_reflash then
    self:reflash_diff()
  end
end

function Collector:reflash_diff()
  local cursor_seq = self.undotree_info.line2seq[vim.fn.line('.')]
  if cursor_seq == nil then return end
  local cseq = self.undotree_info.seq_cur
  if self.float_diff then
    if cursor_seq == cseq then
      win_delete(self.diff_win, true, true)
      win_delete(self.diff_border, true, true)
      self.diff_bufnr = nil
      return
    elseif not self.diff_bufnr then
      self.diff_win, _, self.diff_border = self:create_popup_win("", self.diff_win_opts)
      self.diff_bufnr = vim.api.nvim_win_get_buf(self.diff_win)
      vim.api.nvim_buf_set_option(self.diff_bufnr, "filetype", "undotreeDiff")
    end
  end
  local seq_last = self.undotree_info.seq_last

  self.diff_previewer:update_diff(self.src_bufnr, self.src_winid, self.undotree_win, cseq, cursor_seq, seq_last)

  vim.api.nvim_buf_set_option(self.diff_bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(self.diff_bufnr, 0, -1, false, self.diff_previewer.diff_info)
  for i, hl in ipairs(self.diff_previewer.diff_highlight) do
    vim.api.nvim_buf_add_highlight(self.diff_bufnr, -1, hl, i - 1, 0, -1)
  end
  vim.api.nvim_buf_set_option(self.diff_bufnr, "modifiable", false)
end

function Collector:set_marks(cseq)
  -- >num< : The current state
  local seq_lnum = self.undotree_info.seq2line[cseq]
  local prev_seq_lnum = self.undotree_info.seq2line[self.undotree_info.seq_cur_bak]
  vim.api.nvim_buf_set_option(self.undotree_bufnr, 'modifiable', true)
  if prev_seq_lnum ~= nil then
    vim.fn.setline(prev_seq_lnum, vim.fn.substitute(vim.fn.getline(prev_seq_lnum), '\\zs>\\(\\d\\+\\)<\\ze', '\\1', ''))
  end
  vim.fn.setline(seq_lnum, vim.fn.substitute(vim.fn.getline(seq_lnum), '\\zs\\(\\d\\+\\)\\ze', '>\\1<', ''))
  vim.api.nvim_buf_set_option(self.undotree_bufnr, 'modifiable', false)
end

function Collector:undo2(cseq)
  vim.cmd("noautocmd lua vim.api.nvim_set_current_win(" .. self.src_winid .. ")")
  local cmd
  if cseq == 0 then
    cmd = string.format('silent exe "%s"', 'norm! ' .. self.undotree_info.seq_last .. 'u')
  else
    cmd = string.format('silent exe "%s"', 'undo ' .. cseq)
  end
  vim.cmd(cmd)
  self:reflash_undotree(false)
  vim.cmd("noautocmd lua vim.api.nvim_set_current_win(" .. self.undotree_win .. ")")
  self:set_marks(cseq)
end

function Collector:close()
  win_delete(self.undotree_win, true, true)
  win_delete(self.diff_win, true, true)
  win_delete(self.diff_border, true, true)
  self.src_bufnr = nil
  vim.cmd("noautocmd lua vim.api.nvim_set_current_win(" .. self.src_winid .. ")")
end

return Collector
