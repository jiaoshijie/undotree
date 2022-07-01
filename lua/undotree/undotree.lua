local conf = require('undotree.config')
local if_nil = vim.F.if_nil

local Undotree = {}
Undotree.__index = Undotree

-- [[
-- TODO
-- ]]
local function getStringGraph(curnode, cb, stringGraph, quit_condition, d)
  if d.nseq == quit_condition then
    return 0
  end
  if curnode.seq == d.nseq then
    stringGraph[d.si] = if_nil(stringGraph[d.si], { s = '', i = {} })
    stringGraph[d.si].s = stringGraph[d.si].s ..
        string.rep('s', cb - 1) .. tostring(d.nseq) .. string.rep('s', d.bs - cb)
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
    return getStringGraph(curnode.b[1], cb, stringGraph, quit_condition, d)
  end
  if #curnode.b > 1 then
    stringGraph[d.si] = if_nil(stringGraph[d.si], { s = '', i = {} })
    if conf.contains(d.getp, curnode.seq) == false then
      table.insert(d.getp, curnode.seq)
      if stringGraph[d.si].s == '' then
        stringGraph[d.si].s = stringGraph[d.si].s ..
            string.rep('s', cb - 1) .. string.rep('p', #curnode.b) .. string.rep('s', d.bs - cb)
        d.si = d.si + 1
        d.bs = d.bs + #curnode.b - 1
      end
    end
    local t = 0
    for i, node in ipairs(curnode.b) do
      local bt = getStringGraph(node, cb + i - 1 + t, stringGraph, quit_condition, d)
      t = t + bt
    end
    return #curnode.b - 1 + t
  end
  return 0
end

local function pruningStringGraph(stringGraph)
  for i = 1, #stringGraph[#stringGraph].s, 1 do
    local j = #stringGraph
    if string.sub(stringGraph[j].s, i, i) == 's' then
      while string.sub(stringGraph[j].s, i, i) == 's' do
        stringGraph[j].s = string.sub(stringGraph[j].s, 1, i - 1) ..
            'x' .. string.sub(stringGraph[j].s, i + 1, #stringGraph[#stringGraph].s)
        j = j - 1
      end
    end
  end
end

local function parseEntries(input, output)
  if #input == 0 then return end
  output.b = if_nil(output.b, {})
  for _, e in ipairs(input) do
    local curnode = { seq = e.seq, time = e.time, save = e.save }
    if e.alt ~= nil then
      parseEntries(e.alt, output)
    end
    table.insert(output.b, curnode)
    output = curnode
    output.b = {}
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


function Undotree:new()
  local obj = setmetatable({
    charGraph = {},
    asciimeta = {},
    seq2index = {},
    save2seq = {},

    seq_last = -1,
    seq_cur = -1,
    seq_cur_bak = -1,
  }, self)
  return obj
end

function Undotree:reset()
  self.charGraph = {}
  self.asciimeta = {}
  self.seq2index = {}
  self.save2seq = {}

  self.seq_last = -1
  self.seq_cur = -1
  self.seq_cur_bak = -1
end

function Undotree:getGraphTree()
  -- TODO
  local newtree = vim.fn.undotree()

  self.seq_cur_bak = self.seq_cur
  -- TODO: repeat `this line`
  self.seq_cur = newtree.seq_cur
  if self.seq_last ~= newtree.seq_last then
    self:reset()
    self.seq_cur = newtree.seq_cur
    self.seq_last = newtree.seq_last
    local tree = { seq = 0 }
    parseEntries(newtree.entries, tree)
    local d = { nseq = 0, si = 1, bs = 1, getp = {} }
    local stringGraph = {}
    while d.nseq ~= self.seq_last + 1 do
      getStringGraph(tree, 1, stringGraph, self.seq_last + 1, d)
    end
    pruningStringGraph(stringGraph)

    -- get tree
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
            self.charGraph[i] = string.sub(self.charGraph[i - 1], 1, plen) ..
                string.rep(' |', j - 1 - plen / 2) .. string.rep(' /', ssum + 1)
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
          if i ~= 1 and string.sub(self.charGraph[i - 1], #self.charGraph[i] + 2, #self.charGraph[i] + 2) == '*' then
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
        self.charGraph[#self.charGraph - i] = self.charGraph[#self.charGraph - i] ..
            string.rep(' ', 4) ..
            self.asciimeta[#self.charGraph - i].seq ..
            (self.asciimeta[#self.charGraph - i].save and ' s (' or '   (') ..
            time_ago(self.asciimeta[#self.charGraph - i].time) .. ')'
        -- get seq2lineNumber
        self.asciimeta[#self.charGraph - i].lnum = i + 1
      end
      if #self.charGraph - i == 1 then
        self.charGraph[#self.charGraph - i] = self.charGraph[#self.charGraph - i] ..
            string.rep(' ', 4) .. self.asciimeta[1].s
        self.asciimeta[1].lnum = i + 1
      end
      i = i + 1
    end
  end
end

return Undotree
