local undotree = {}
local if_nil = vim.F.if_nil
local actions = require('undotree.actions')
-- node = {seq='number', time='number', save='number', b='table'}

function undotree:new()
  local newObj = {}
  newObj.undotreeName = 'undotree_tree_buf'
  newObj.undotreeFloatName = 'undotree_float_diff_buf'
  newObj.bufnr = -1
  newObj.targetbufnr = -1
  newObj.diffbufnr = -1
  newObj.diffbufnr_border = -1

  newObj.charGraph = {}
  newObj.asciimeta = {}
  newObj.seq2index = {}
  newObj.save2seq = {}

  newObj.seq_last = -1
  newObj.seq_cur = -1
  newObj.seq_cur_bak = -1

  self.__index = self
  return setmetatable(newObj, self)
end

local v_have = function(listp, item)
  for _, v in ipairs(listp) do
    if v == item then
      return true
    end
  end
  return false
end

local function stringGraph_recursion(curnode, cb, stringGraph, quit_condition, d)
  if d.nseq == quit_condition then
    return 0
  end
  if curnode.seq == d.nseq then
    stringGraph[d.si] = if_nil(stringGraph[d.si], {s='', i={}})
    stringGraph[d.si].s = stringGraph[d.si].s .. string.rep('s', cb - 1) .. tostring(d.nseq) .. string.rep('s', d.bs - cb)
    stringGraph[d.si].i.seq = d.nseq
    stringGraph[d.si].i.time = curnode.time
    stringGraph[d.si].i.save = curnode.save
    d.nseq = d.nseq + 1
    d.si = d.si + 1
  end
  if curnode.b == nil or #curnode.b == 0 then
    return 0
  end
  if #curnode.b == 1 then
    return stringGraph_recursion(curnode.b[1], cb, stringGraph, quit_condition, d)
  end
  if #curnode.b > 1 then
    stringGraph[d.si] = if_nil(stringGraph[d.si], {s='', i={}})
    if v_have(d.getp, curnode.seq) == false then
      table.insert(d.getp, curnode.seq)
      if stringGraph[d.si].s == '' then
        stringGraph[d.si].s = stringGraph[d.si].s .. string.rep('s', cb - 1) .. string.rep('p', #curnode.b) .. string.rep('s', d.bs - cb)
        d.si = d.si + 1
        d.bs = d.bs + #curnode.b - 1
      end
    end
    local t = 0
    for i, node in ipairs(curnode.b) do
      local bt = stringGraph_recursion(node, cb + i - 1 + t, stringGraph, quit_condition, d)
      t = t + bt
    end
    return #curnode.b - 1 + t
  end
  return 0
end

local replaceUsefulLeaveS2X = function(stringGraph)
  for i = 1, #stringGraph[#stringGraph].s, 1 do
    local j = #stringGraph
    if string.sub(stringGraph[j].s, i, i) == 's' then
      while string.sub(stringGraph[j].s, i, i) == 's' do
        stringGraph[j].s = string.sub(stringGraph[j].s, 1, i - 1) .. 'x' .. string.sub(stringGraph[j].s, i + 1, #stringGraph[#stringGraph].s)
        j = j - 1
      end
    end
  end
end

local time_ago = function(ptime)
  local sec = vim.fn.localtime() - ptime
  local mf = math.floor
  if sec < 60 then
    return mf(sec) .. ' seconds ago'
  elseif sec < 3600 then
    return mf(sec / 60) .. ' minutes ago'
  elseif sec < 86400 then
    return mf(sec / 3600) .. ' hours ago'
  end
  return mf(sec / 86400) .. ' days ago'
end


function undotree:clear()
  self.bufnr = -1
  self.targetbufnr = -1
  self.diffbufnr = -1
  self.diffbufnr_border = -1

  self.charGraph = {}
  self.asciimeta = {}
  self.seq2index = {}
  self.save2seq = {}

  self.seq_last = -1
  self.seq_cur = -1
  self.seq_cur_bak = -1
end

function undotree:parseEntries(input, output)
  if #input == 0 then return end
  output.b = if_nil(output.b, {})
  for _, e in ipairs(input) do
    local curnode = {seq=e.seq, time=e.time, save=e.save}
    if e.alt ~= nil then
      undotree:parseEntries(e.alt, output)
    end
    table.insert(output.b, curnode)
    output = curnode
    output.b = {}
  end
end


function undotree:getGraphInfo(tree)
  local d = { nseq = 0, si = 1, bs = 1, getp = {} }
  local stringGraph = {}
  while d.nseq ~= self.seq_last + 1 do
    stringGraph_recursion(tree, 1, stringGraph, self.seq_last + 1, d)
  end
  replaceUsefulLeaveS2X(stringGraph)
  -- get info
  local i = 1
  for _, t in ipairs(stringGraph) do
    self.charGraph[i] = ''
    local j = 1
    while j <= #t.s do
      if string.sub(t.s, j, j) == 's' then
        self.charGraph[i] = self.charGraph[i] .. ' |'
        j = j + 1
      elseif string.sub(t.s, j, j) == 'p' then
        local ssum = 0
        for issnum = j, #t.s, 1 do
          if string.sub(t.s, issnum, issnum) == 's' then
            ssum = ssum + 1
          end
        end
        local plen = #self.charGraph[i]
        self.charGraph[i] = self.charGraph[i] .. ' |'
        j = j + 1
        self.charGraph[i] = self.charGraph[i] .. string.rep(' /', ssum + 1)
        j = j + 1
        while j <= #t.s and string.sub(t.s, j, j) == 'p' do
          i = i + 1
          self.charGraph[i] = string.sub(self.charGraph[i - 1], 1, plen) .. string.rep(' |', j - 1 - plen / 2) .. string.rep(' /', ssum + 1)
          j = j + 1
        end
        break
      elseif string.sub(t.s, j, j) == 'x' then
        if string.find(t.s, string.rep('x', #t.s - j + 1), j, true) then
          break
        end
        self.charGraph[i] = self.charGraph[i] .. '  '
        j = j + 1
      else
        -- make the tree more beautiful when only one branch
        if i~= 1 and string.sub(self.charGraph[i - 1], #self.charGraph[i] + 2, #self.charGraph[i] + 2) == '*' then
          self.charGraph[i + 1] = '' .. self.charGraph[i]
          self.charGraph[i] = self.charGraph[i] .. string.rep(' |', (#self.charGraph[i - 1] - #self.charGraph[i]) / 2)
          i = i + 1
        end
        while j <= #t.s and tonumber(string.sub(t.s, j, j)) do j = j + 1 end
        self.charGraph[i] = self.charGraph[i] .. ' *'
        self.asciimeta[i] = if_nil(self.asciimeta[i], {})
        self.asciimeta[i].seq = t.i.seq
        if t.i.seq == 0 then
          self.asciimeta[i].s = "(Original)"
        else
          self.asciimeta[i].time = t.i.time
        end
        self.seq2index[t.i.seq] = i
        if t.i.save then
          self.asciimeta[i].save = t.i.save
          self.save2seq[t.i.save] = t.i.seq
        end
        -- charGraph[i] = charGraph[i] .. ' ' .. tonumber(string.sub(s, j, j))  -- NOTICE: looks so ugly
      end
    end
    i = i + 1
  end
  i = 0
  while i < #self.charGraph do
    if #self.charGraph - i ~= 1 and self.asciimeta[#self.charGraph - i] ~= nil then
      self.charGraph[#self.charGraph - i] = self.charGraph[#self.charGraph - i] .. string.rep(' ', 4) .. self.asciimeta[#self.charGraph - i].seq .. (self.asciimeta[#self.charGraph - i].save and ' s (' or '   (') .. time_ago(self.asciimeta[#self.charGraph - i].time) .. ')'
      -- get seq2lineNumber
      self.asciimeta[#self.charGraph - i].lnum = i + 1
    end
    if #self.charGraph - i == 1 then
      self.charGraph[#self.charGraph - i] = self.charGraph[#self.charGraph - i] .. string.rep(' ', 4) .. self.asciimeta[1].s
      self.asciimeta[1].lnum = i + 1
    end
    i = i + 1
  end
end

function undotree:setMark(cseq, clnum)
  -- >num< : The current state
  if cseq == self.seq_cur or self.seq_cur == 0 then
    return
  end
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', true)
  local seq_lnum = clnum and clnum or self.asciimeta[self.seq2index[self.seq_cur]].lnum
  vim.fn.setline(seq_lnum, vim.fn.substitute(vim.fn.getline(seq_lnum), '\\zs\\(\\d\\+\\)\\ze', '>\\1<', ''))
  self.seq_cur = cseq and cseq or self.seq_cur
  if self.seq_cur_bak ~= -1 and self.seq_cur_bak ~= self.seq_cur then
    seq_lnum = self.asciimeta[self.seq2index[self.seq_cur_bak]].lnum
    vim.fn.setline(seq_lnum, vim.fn.substitute(vim.fn.getline(seq_lnum), '\\zs>\\(\\d\\+\\)<\\ze', '\\1', ''))
  end
  self.seq_cur_bak = self.seq_cur
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', false)
end

function undotree:graph2buf()
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', true)
  -- clear the buf
  if vim.fn.bufnr() ~= self.bufnr then
    local ev_bak = vim.opt.eventignore:get()
    vim.opt.eventignore = { "BufEnter","BufLeave","BufWinLeave","InsertLeave","CursorMoved","BufWritePost" }
    vim.cmd(string.format('silent exe "%s"', "norm! " .. vim.fn.bufwinnr(self.bufnr) .. "\\<c-w>\\<c-w>"))
    vim.opt.eventignore = ev_bak
  end
  vim.cmd[[silent exe '1,$ d _']]
  local i = 0
  while i < #self.charGraph do
    vim.api.nvim_buf_set_lines(self.bufnr, i, i + 1, false, { self.charGraph[#self.charGraph - i] })
    i = i + 1
  end
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', false)
end

function undotree:update_undotree()
  if vim.fn.bufwinnr(self.bufnr) == -1 then
    actions.create_undo_window(self)
  end
  self:graph2buf()
end

return undotree
