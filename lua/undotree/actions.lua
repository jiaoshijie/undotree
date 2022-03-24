local actions = {}
local update_diff = require('undotree.diff').update_diff
local ui = require('undotree.ui')

local jump2star = function(direction)
  local lnum = vim.fn.line('.')
  while lnum > vim.fn.line('^') and lnum <= vim.fn.line('$') do
    lnum = lnum + direction
    local col = actions.findStar(lnum)
    if col then
      vim.fn.cursor({lnum, col})
      break
    end
  end
end

local setTargetFocus = function()
  local winnr = vim.fn.bufwinnr(Jsj_undotree.targetbufnr)
  if winnr == -1 then return false end
  vim.cmd(string.format('silent exe "%s"', "norm! " .. winnr .. "\\<c-w>\\<c-w>"))
  return true
end

local actionInTarget = function(cmd)
  local ev_bak = vim.opt.eventignore:get()
  vim.opt.eventignore = { "BufEnter","BufLeave","BufWinLeave","InsertLeave","CursorMoved","BufWritePost" }
  if not setTargetFocus() then return end
  vim.cmd(cmd)
  actions.setFocus()
  vim.opt.eventignore = ev_bak
end

actions.findStar = function(lnum)
  local line = vim.fn.getline(lnum)
  local i = 1
  while i <= #line do
    if string.sub(line, i, i) == '*' then
      return i
    end
    i = i + 1
  end
  return nil
end

actions.setFocus = function()
  if vim.fn.bufnr() == Jsj_undotree.bufnr then return end
  local winnr = vim.fn.bufwinnr(Jsj_undotree.bufnr)
  if winnr == -1 then return end
  vim.cmd(string.format('silent exe "%s"', "norm! " .. winnr .. "\\<c-w>\\<c-w>"))
end

actions.prev_star = function()
  jump2star(-1)
  update_diff()
end

actions.next_star = function()
  jump2star(1)
  update_diff()
end

actions.prev_state = function()
  jump2star(-1)
  actions.actionEnter()
end

actions.next_state = function()
  jump2star(1)
  actions.actionEnter()
end

actions.quit_undotree = function()
  ui.quit_diff_win()
  ui.quit_undotree_split()
  Jsj_undotree = nil
end

actions.quit_diff_win = function()
  ui.quit_diff_win()
end

actions.undo2 = function(cseq)
  if cseq == 0 then
    actionInTarget(string.format('silent exe "%s"', 'norm! ' .. Jsj_undotree.seq_last .. 'u'))
    return
  end
  actionInTarget(string.format('silent exe "%s"', 'undo ' .. cseq))
end

actions.actionEnter = function()
  local info = Jsj_undotree.asciimeta[#Jsj_undotree.charGraph - vim.fn.line('.') + 1]
  if info == nil then
    return
  end
  actions.undo2(info.seq)
  Jsj_undotree:setMark(info.seq, vim.fn.line('.'))
  Jsj_undotree.seq_cur = info.seq
  update_diff()
end

actions.showOrFocusDiffWindow = function()
  local winnr = vim.fn.bufwinnr(Jsj_undotree.diffbufnr)
  if winnr == -1 then
    update_diff()
  else
    vim.cmd(string.format('silent exe "%s"', "norm! " .. winnr .. "\\<c-w>\\<c-w>"))
  end
end

return actions
