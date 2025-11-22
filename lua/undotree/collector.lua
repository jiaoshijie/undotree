local undotree = require("undotree.undotree")
local Diff = require("undotree.diff")
local split_win = require("undotree.split_window")
local action = require("undotree.action")

---@class UndoTreeCollector.Opts
local default_opt = {
  ---@type boolean
  float_diff = true, -- set this `true` will disable layout option

  ---@type string[]
  ignore_filetype = {
    "undotree",
    "undotreeDiff",
    "qf",
  },

  ---@type UndoTree
  undotree_info = undotree.new(),

  ---@type "left_bottom"|"left_left_bottom"
  layout = "left_bottom",

  ---@type "left"|"right"|"bottom"
  position = "left",

  ---@type UndoTreeDiff
  diff_previewer = Diff:new(),

  ---@class UndoTreeCollector.WinOpts
  ---@field border? string
  window = {
    winblend = 30,
    -- TODO: maybe change it to a suitable number
    height = 0,
    width = 0,
    border = "rounded",
  },

  ---@type table<string, string>
  keymaps = {
    j = "move_next",
    k = "move_prev",
    gj = "move2parent",
    J = "move_change_next",
    K = "move_change_prev",
    ["<cr>"] = "action_enter",
    p = "enter_diffbuf",
    q = "quit",
  },
}

---@param lnum string|integer
---@return boolean
---@return integer
local function find_star(lnum)
  local found, pos = false, 0
  local line = vim.fn.getline(lnum)

  if not line or line == "" then
    return found, pos
  end

  local col = 1
  while col <= #line do
    if line:sub(col, col) == "*" then
      found, pos = true, col - 1 -- found, position
      break
    end
    col = col + 1
  end

  return found, pos
end

---@param bufnr? integer
local function buf_delete(bufnr)
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

---@param win_id integer
---@param force boolean
---@param bdelete? boolean
local function win_delete(win_id, force, bdelete)
  if win_id == nil or type(win_id) ~= "number" or not vim.api.nvim_win_is_valid(win_id) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(win_id)

  if bdelete ~= nil and bdelete then
    buf_delete(bufnr)
  end

  if not vim.api.nvim_win_is_valid(win_id) then
    return
  end

  vim.api.nvim_win_close(win_id, force)
end

---@class UndoTreeCollector: UndoTreeCollector.Opts
local Collector = {}

---@param opts? UndoTreeCollector.Opts
function Collector.new(opts)
  opts = opts or {}

  local obj = setmetatable(vim.tbl_deep_extend("keep", opts, default_opt, Collector), {
    __index = Collector,
  })

  return obj
end

function Collector:run()
  if vim.fn.win_gettype() == "command" then
    print("WARNING: Unable to open from command-line window: `:h E11`")
    return
  end

  if vim.tbl_contains(self.ignore_filetype, vim.bo.filetype) then
    return
  end

  self.src_winid = vim.api.nvim_get_current_win()
  self.src_bufnr = vim.api.nvim_get_current_buf()

  local line_count = vim.o.lines - vim.o.cmdheight
  if vim.o.ls ~= 0 then
    line_count = line_count - 1
  end

  if vim.fn.exists("+winbar") ~= 0 and vim.o.winbar ~= "" then
    line_count = line_count - 1
  end

  local win_opts = self:get_window_option(vim.o.columns, line_count)
  local u_win = split_win:create("", win_opts.undotree_opts)

  self.undotree_win, self.undotree_bufnr = u_win, vim.api.nvim_win_get_buf(u_win)

  vim.api.nvim_set_option_value("filetype", "undotree", { buf = self.undotree_bufnr })

  if self.float_diff then
    self.diff_win_opts = win_opts.diff_opts
  else
    self.diff_win = split_win:create("", win_opts.diff_opts)
    self.diff_bufnr = vim.api.nvim_win_get_buf(self.diff_win)

    vim.api.nvim_set_option_value("filetype", "undotreeDiff", { buf = self.diff_bufnr })
  end

  self:reflash_undotree(true)

  -- Always enter to undotree window
  vim.cmd("noautocmd lua vim.api.nvim_set_current_win(" .. self.undotree_win .. ")")
  self:set_marks(self.undotree_info.seq_cur)

  for k, v in pairs(self.keymaps) do
    vim.keymap.set("n", k, function()
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
      self.src_bufnr = nil
    end,
  })
end

---@param self UndoTreeCollector
---@param bufnr integer
function Collector:create_popup_win(bufnr, popup_opts)
  local win = vim.api.nvim_open_win(bufnr, false, popup_opts)

  vim.api.nvim_set_option_value("winblend", self.window.winblend, { win = win })
  vim.api.nvim_set_option_value("wrap", false, { win = win })
  if vim.fn.exists("+winbar") ~= 0 then
    vim.api.nvim_set_option_value("winbar", nil, { win = win })
  end

  return win
end

---@param self UndoTreeCollector
---@param max_columns integer
---@param max_lines integer
---@return UndoWinTree
function Collector:get_window_option(max_columns, max_lines)
  local min_columns, min_lines = math.floor(max_columns * 0.25), math.floor(max_lines * 0.30)

  ---@class UndoWinTree
  local opts = {}
  ---@class UndoWinTree.Opts
  ---@field enter? boolean
  opts.undotree_opts = {}
  opts.diff_opts = {}

  if self.position == "bottom" then
    -- `size` is the height of the undotree_window
    self.window.height = self.window.height or 0
    local height = math.max(self.window.height, min_lines)
    opts.undotree_opts.size = math.min(height, max_lines)
  else -- self.positon == "left" or "right"
    -- `size` is the width of the undotree_window
    self.window.width = self.window.width or 0
    local width = math.max(self.window.width, min_columns)
    opts.undotree_opts.size = math.min(width, max_columns)
  end
  opts.undotree_opts.position = self.position
  if not self.float_diff and self.layout == "left_left_bottom" then
    opts.undotree_opts.enter = true
  else
    opts.undotree_opts.enter = false
  end

  if self.float_diff then
    local height = math.floor(max_lines * 0.8)

    opts.diff_opts.relative = "editor"
    opts.diff_opts.row = math.floor((max_lines - height) / 2)
    opts.diff_opts.height = height
    opts.diff_opts.style = "minimal"
    opts.diff_opts.border = self.window.border or "rounded"
    opts.diff_opts.title = "Diff Previewer"
    opts.diff_opts.title_pos = "center"
    opts.diff_opts.noautocmd = true

    if self.position == "right" then
      opts.diff_opts.col = opts.undotree_opts.size - 15
      opts.diff_opts.width = math.floor((max_columns - (opts.undotree_opts.size + 10)) * 0.8)
    elseif self.position == "left" then
      opts.diff_opts.col = opts.undotree_opts.size + 10
      opts.diff_opts.width = math.floor((max_columns - opts.diff_opts.col) * 0.8)
    else -- self.position == "bottom"
      opts.diff_opts.col = math.floor(max_columns * 0.15)
      opts.diff_opts.width = math.floor(max_columns * 0.7)
    end
    -- borderhighlight, highlight, titlehighlight
  else
    self.window.height = self.window.height or 0
    local height = math.max(self.window.height, min_lines)
    opts.diff_opts.size = math.min(height, max_lines)
    opts.diff_opts.enter = false
    opts.diff_opts.position = self.layout == "left_bottom" and "bottom" or "left_botom"
  end

  return opts
end

---@param self UndoTreeCollector
---@param always_flash boolean
function Collector:reflash_undotree(always_flash)
  vim.cmd("noautocmd lua vim.api.nvim_set_current_win(" .. self.src_winid .. ")")

  local reflash = self.undotree_info:gen_graph_tree()

  if not (always_flash or reflash) then
    return
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = self.undotree_bufnr })
  vim.api.nvim_buf_set_lines(self.undotree_bufnr, 0, -1, false, self.undotree_info.char_graph)
  vim.api.nvim_set_option_value("modifiable", false, { buf = self.undotree_bufnr })
end

---@param self UndoTreeCollector
---@param change integer
---@param not_reflash? boolean
function Collector:move_selection(change, not_reflash)
  local lnum = vim.fn.line(".") + change
  local col, found = 0, false

  while lnum >= 1 and lnum <= vim.fn.line("$") do
    found, col = find_star(lnum)
    if found then
      self:set_selection({ lnum, col }, not_reflash)
      return
    end
    lnum = lnum + change
  end
end

---@param self UndoTreeCollector
---@param pos [integer, integer]
---@param not_reflash? boolean
function Collector:set_selection(pos, not_reflash)
  vim.api.nvim_win_set_cursor(self.undotree_win, pos)
  if not not_reflash then
    self:reflash_diff()
  end
end

---@param self UndoTreeCollector
function Collector:reflash_diff()
  local cursor_seq = self.undotree_info.line2seq[vim.fn.line(".")]

  if cursor_seq == nil then
    return
  end

  local cseq = self.undotree_info.seq_cur
  if self.float_diff and cursor_seq == cseq then
    win_delete(self.diff_win, true, true)
    self.diff_bufnr = nil
    self.diff_win = nil
    return
  elseif self.float_diff and not self.diff_bufnr then
    self.diff_bufnr = vim.api.nvim_create_buf(false, true)
    assert(self.diff_bufnr ~= 0, "create diff buf failed")
    self.diff_win = self:create_popup_win(self.diff_bufnr, self.diff_win_opts)
    assert(self.diff_win ~= 0, "create diff floating window failed")
    vim.api.nvim_set_option_value("filetype", "undotreeDiff", { buf = self.diff_bufnr })
  end
  local seq_last = self.undotree_info.seq_last

  self.diff_previewer:update_diff(
    self.src_bufnr,
    self.src_winid,
    self.undotree_win,
    cseq,
    cursor_seq,
    seq_last
  )

  local ns = vim.api.nvim_create_namespace("undotree_diff_preview_ns")
  vim.api.nvim_set_option_value("modifiable", true, { buf = self.diff_bufnr })
  vim.api.nvim_buf_set_lines(self.diff_bufnr, 0, -1, false, self.diff_previewer.diff_info)
  for i, hl in ipairs(self.diff_previewer.diff_highlight) do
    vim.hl.range(self.diff_bufnr, ns, hl, { i - 1, 0 }, { i - 1, -1 }, { timeout = -1 })
  end
  vim.api.nvim_set_option_value("modifiable", false, { buf = self.diff_bufnr })
end

---@param self UndoTreeCollector
---@param cseq integer
function Collector:set_marks(cseq)
  -- >num< : The current state
  local seq_lnum = self.undotree_info.seq2line[cseq]
  local prev_seq_lnum = self.undotree_info.seq2line[self.undotree_info.seq_cur_bak]
  vim.api.nvim_set_option_value("modifiable", true, { buf = self.undotree_bufnr })
  if prev_seq_lnum ~= nil then
    vim.fn.setline(
      prev_seq_lnum,
      vim.fn.substitute(vim.fn.getline(prev_seq_lnum), "\\zs>\\(\\d\\+\\)<\\ze", "\\1", "")
    )
  end
  vim.fn.setline(
    seq_lnum,
    vim.fn.substitute(vim.fn.getline(seq_lnum), "\\zs\\(\\d\\+\\)\\ze", ">\\1<", "")
  )
  vim.api.nvim_set_option_value("modifiable", false, { buf = self.undotree_bufnr })
end

---@param self UndoTreeCollector
---@param cseq? integer
function Collector:undo2(cseq)
  if cseq == nil then
    return
  end

  vim.cmd("noautocmd lua vim.api.nvim_set_current_win(" .. self.src_winid .. ")")
  local cmd
  if cseq == 0 then
    cmd = string.format('silent exe "%s"', "norm! " .. self.undotree_info.seq_last .. "u")
  else
    cmd = string.format('silent exe "%s"', "undo " .. cseq)
  end
  vim.cmd(cmd)
  self:reflash_undotree(false)
  vim.cmd("noautocmd lua vim.api.nvim_set_current_win(" .. self.undotree_win .. ")")
  self:set_marks(cseq)
end

---@param self UndoTreeCollector
function Collector:close()
  win_delete(self.undotree_win, true, true)
  win_delete(self.diff_win, true, true)
  self.src_bufnr = nil
  vim.cmd("noautocmd lua vim.api.nvim_set_current_win(" .. self.src_winid .. ")")
end

return Collector

-- vim:ts=2:sts=2:sw=2:et:ai:si:sta:
