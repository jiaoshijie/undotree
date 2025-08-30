local function undo2(cseq, seq_last)
  local cmd
  if cseq == 0 then
    cmd = string.format('silent exe "%s"', 'norm! ' .. seq_last .. 'u')
  else
    cmd = string.format('silent exe "%s"', 'undo ' .. cseq)
  end
  vim.cmd(cmd)
end

---@class UndoTreeDiff
local Diff = {}

function Diff:new()
  local obj = setmetatable({
    old_seq = nil,
    new_seq = nil,
    diff_info = {},
    diff_highlight = {},
  }, { __index = Diff })

  return obj
end

function Diff:set(old, new)
  self.old_seq = old
  self.new_seq = new
  self.diff_info = {}
  self.diff_highlight = {}
end

function Diff:update_diff(src_buf, src_win, undo_win, old_seq, new_seq, seq_last)
  if old_seq == self.old_seq and new_seq == self.new_seq then
    return
  end
  self:set(old_seq, new_seq)
  table.insert(self.diff_info, old_seq .. ' --> ' .. new_seq)
  table.insert(self.diff_highlight, 'UndotreeDiffLine')

  if old_seq == new_seq then
    return
  end
  local old_buf_con = vim.api.nvim_buf_get_lines(src_buf, 0, -1, false)
  vim.cmd("noautocmd lua vim.api.nvim_set_current_win(" .. src_win .. ")")
  local savedview = vim.fn.winsaveview()
  undo2(new_seq, seq_last)
  local new_buf_con = vim.api.nvim_buf_get_lines(src_buf, 0, -1, false)
  undo2(old_seq, seq_last)
  vim.fn.winrestview(savedview)
  vim.cmd("noautocmd lua vim.api.nvim_set_current_win(" .. undo_win .. ")")

  local on_hunk_callback = function(start_old, count_old, start_new, count_new)
    table.insert(self.diff_info,
      "@@ -" .. start_old .. "," .. count_old .. " " .. start_new .. "," .. count_new .. " @@")
    table.insert(self.diff_highlight, "UndotreeDiffLine")
    if count_old ~= 0 then
      for i = 0, count_old - 1 do
        table.insert(self.diff_info, "- " .. old_buf_con[start_old + i])
        table.insert(self.diff_highlight, "UndotreeDiffRemoved")
      end
    end
    if count_new ~= 0 then
      for i = 0, count_new - 1 do
        table.insert(self.diff_info, "+ " .. new_buf_con[start_new + i])
        table.insert(self.diff_highlight, "UndotreeDiffAdded")
      end
    end
  end

  vim.diff(table.concat(old_buf_con, '\n'), table.concat(new_buf_con, '\n'), {
    result_type = "indices",
    on_hunk = on_hunk_callback,
    algorithm = "histogram",
  })
end

return Diff
