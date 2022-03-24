local undotree = require('undotree.undotree')
local actions = require('undotree.actions')
local _M = {}

local function update()
  if vim.bo.filetype == 'undotree' or vim.bo.filetype == 'qf' then
    return
  end
  if Jsj_undotree == nil then
    Jsj_undotree = undotree:new()
  end
  Jsj_undotree.targetbufnr = vim.fn.bufnr()  -- set really undo buf
  local newtree = vim.fn.undotree()
  Jsj_undotree.seq_cur = newtree.seq_cur
  if Jsj_undotree.seq_last ~= newtree.seq_last then
    Jsj_undotree.seq_last = newtree.seq_last
    Jsj_undotree:clear()
    local tree = {seq=0}
    Jsj_undotree:parseEntries(newtree.entries, tree)
    Jsj_undotree:getGraphInfo(tree)
  end
  Jsj_undotree:update_undotree()
  actions.setFocus()
  local lnum = Jsj_undotree.asciimeta[Jsj_undotree.seq2index[Jsj_undotree.seq_cur]].lnum
  vim.fn.cursor({lnum, actions.findStar(lnum)})
  Jsj_undotree:setMark()
end

_M.toggle = function()
  if Jsj_undotree ~= nil and vim.fn.bufwinnr(Jsj_undotree.bufnr) ~= -1 then
    actions.quit_undotree()
    return
  end
  update()
end

return _M
