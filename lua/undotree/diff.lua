local fmt = string.format

---@param cseq integer
---@param seq_last integer
local function undo2(cseq, seq_last)
  local cmd =
    fmt('silent exe "%s"', (cseq == 0 and ("norm!" .. seq_last .. "u") or ("undo" .. cseq)))
  vim.cmd(cmd)
end

---@class UndoTreeDiff
---@field old_seq integer
---@field new_seq integer
---@field diff_info table
---@field diff_highlight table
local Diff = {}

---@return UndoTreeDiff obj
function Diff:new()
  local obj = setmetatable({
    old_seq = nil,
    new_seq = nil,
    diff_info = {},
    diff_highlight = {},
  }, { __index = Diff })

  return obj
end

---@param old integer
---@param new integer
function Diff:set(old, new)
  self.old_seq, self.new_seq = old, new
  self.diff_info, self.diff_highlight = {}, {}
end

---@param src_buf integer
---@param src_win integer
---@param undo_win integer
---@param old_seq integer
---@param new_seq integer
---@param seq_last integer
function Diff:update_diff(src_buf, src_win, undo_win, old_seq, new_seq, seq_last)
  if old_seq == self.old_seq and new_seq == self.new_seq then
    return
  end
  self:set(old_seq, new_seq)
  table.insert(self.diff_info, old_seq .. " --> " .. new_seq)
  table.insert(self.diff_highlight, "UndotreeDiffLine")

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
    table.insert(
      self.diff_info,
      fmt("@@ -%s,%s ,%s @@", start_old, count_old, start_new, count_new)
    )
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

  vim.diff(table.concat(old_buf_con, "\n"), table.concat(new_buf_con, "\n"), {
    result_type = "indices",
    on_hunk = on_hunk_callback,
    algorithm = "histogram",
  })
end

return Diff

-- vim:ts=2:sts=2:sw=2:et:ai:si:sta:
