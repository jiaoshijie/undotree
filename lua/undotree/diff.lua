local Diff = {}
Diff.__index = Diff

local undo2 = function(cseq, seq_last)
  local cmd
  if cseq == 0 then
    cmd = string.format('silent exe "%s"', 'norm! ' .. seq_last .. 'u')
  else
    cmd = string.format('silent exe "%s"', 'undo ' .. cseq)
  end
  vim.cmd(cmd)
end

function Diff:new()
  local obj = setmetatable({
    old_seq = nil,
    new_seq = nil,
    diff_info = {},
    diff_highlight = {},
  }, self)
  return obj
end

function Diff:set(old, new)
  self.old_seq = old
  self.new_seq = new
  self.diff_info = {}
  self.diff_highlight = {}
end

function Diff:parse_diff(diff_lines)
  for _, line in ipairs(diff_lines) do
    local ch = string.sub(line, 1, 1)
    if ch == '<' or ch == '>' then
      local prefix = ch == '<' and '- ' or '+ '
      local hlgroup = ch == '<' and 'UndotreeDiffRemoved' or 'UndotreeDiffAdded'
      table.insert(self.diff_info, prefix .. line:sub(3))
      table.insert(self.diff_highlight, hlgroup)
    elseif ch ~= '-' then
      table.insert(self.diff_info, line)
      table.insert(self.diff_highlight, 'UndotreeDiffLine')
    end
  end
end

function Diff:update_diff(src_buf, src_win, undo_win, old_seq, new_seq, seq_last)
  if old_seq == self.old_seq and new_seq == self.new_seq then
    return
  end
  self:set(old_seq, new_seq)
  table.insert(self.diff_info, old_seq .. ' --> ' .. new_seq)
  table.insert(self.diff_highlight, 'UndotreeDiffLine')

  if old_seq ~= new_seq then
    local old_buf_con = vim.api.nvim_buf_get_lines(src_buf, 0, -1, false)
    vim.cmd("noautocmd lua vim.api.nvim_set_current_win(" .. src_win .. ")")
    local savedview = vim.fn.winsaveview()
    undo2(new_seq, seq_last)
    local new_buf_con = vim.api.nvim_buf_get_lines(src_buf, 0, -1, false)
    undo2(old_seq, seq_last)
    vim.fn.winrestview(savedview)
    vim.cmd("noautocmd lua vim.api.nvim_set_current_win(" .. undo_win .. ")")
    local tempfile1 = vim.fn.tempname() -- old buf
    local tempfile2 = vim.fn.tempname() -- new buf

    local ok, err = pcall(vim.fn.writefile, old_buf_con, tempfile1)
    if not ok then
      vim.api.nvim_err_writeln(err)
    end
    ok, err = pcall(vim.fn.writefile, new_buf_con, tempfile2)
    if not ok then
      vim.api.nvim_err_writeln(err)
    end

    local diff_res = vim.fn.split(vim.fn.system('diff ' .. tempfile1 .. ' ' .. tempfile2), '\n')

    os.remove(tempfile1)
    os.remove(tempfile2)

    self:parse_diff(diff_res)
  end
end

return Diff
