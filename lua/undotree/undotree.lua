local mf = math.floor

---@class OtherInfo
---@field save integer
---@field time integer
---@field lnum integer
---@field parent integer

local conf = require("undotree.config")

---@param ptime integer
---@return string
local function time_ago(ptime)
  local sec = vim.fn.localtime() - ptime
  local mft

  if sec < 60 then
    mft = mf(sec)
    return ("(%s %s ago)"):format(mft, (mft > 1 and "secs" or "sec"))
  end

  if sec < 3600 then
    mft = mf(sec / 60)
    return ("(%s %s ago)"):format(mft, (mft > 1 and "mins" or "min"))
  end

  if sec < 86400 then
    mft = mf(sec / 3600)
    return ("(%s %s ago)"):format(mft, (mft > 1 and "hours" or "hour"))
  end

  mft = mf(sec / 86400)
  return ("(%s %s ago)"):format(mft, (mft > 1 and "days" or "day"))
end

---@class UndoTreeNode
---@field seq? integer
---@field time? integer|nil
---@field save? integer|nil
---@field indent? integer
---@field children? UndoTreeNode[]
---@field parent? integer
local Node = {}

---@param seq integer
---@param time integer|nil
---@param save integer|nil
---@return UndoTreeNode node
function Node.new(seq, time, save)
  local node = setmetatable({}, { __index = Node })
  node.seq = seq
  node.time = time
  node.save = save
  node.children = {}

  return node
end

---@param input vim.fn.undotree.entry[]
---@param output UndoTreeNode
local function parse_entries(input, output)
  if vim.tbl_isempty(input) then
    return
  end

  for _, n in ipairs(input) do
    if n.alt ~= nil then
      parse_entries(n.alt, output)
    end

    local new_node = Node.new(n.seq, n.time, n.save)
    table.insert(output.children, new_node)
    output = new_node
  end
end

---@param tree UndoTreeNode
---@param indent integer
---@return integer ind
local function gen_indentions(tree, indent)
  tree.indent = indent
  local ind = tree.indent
  for i, n in ipairs(tree.children) do
    if i ~= 1 then
      ind = ind + 1
    end
    n.parent = tree.seq
    ind = gen_indentions(n, ind)
  end

  return ind
end

---@param graph string[]
---@param index integer
---@param char string
---@param indent integer
local function set_line(graph, index, char, indent)
  if vim.tbl_isempty(graph) then
    error("undotree - set_line: empty graph!")
  end

  local line = graph[index]
  local line_len = line:len()

  if line_len >= indent * 2 + 1 then
    graph[index] = line:sub(1, indent * 2) .. char .. line:sub(indent * 2 + 2)
  else
    graph[index] = line .. string.rep(" ", indent * 2 - line_len) .. char
  end
end

---@param tree UndoTreeNode
---@param graph string[]
---@param line2seq integer[]
---@param other_info OtherInfo[]
---@param seq integer
---@param parent_ind integer
---@return boolean
local function draw(tree, graph, line2seq, other_info, seq, parent_ind)
  if tree.seq == seq then
    local parent_lnum = other_info[tree.parent].lnum
    local parent_line = graph[parent_lnum]
    local parent_line_len = parent_line:len()

    if parent_line_len < tree.indent * 2 + 1 then
      graph[parent_lnum] = parent_line .. string.rep("-", tree.indent * 2 + 1 - parent_line_len)
    elseif parent_line_len > tree.indent * 2 + 1 then
      graph[parent_lnum] = parent_line:sub(1, parent_ind * 2 + 1)
        .. string.rep("-", (tree.indent - parent_ind) * 2)
        .. parent_line:sub(tree.indent * 2 + 2)
    end

    if parent_lnum == #graph then
      table.insert(graph, string.rep(" ", tree.indent * 2) .. "|")
    else
      for lnum = parent_lnum + 1, #graph do
        set_line(graph, lnum, "|", tree.indent)
      end
    end

    table.insert(graph, string.rep(" ", tree.indent * 2) .. "*")
    line2seq[#graph] = seq
    other_info[seq] = {
      save = tree.save,
      time = tree.time,
      lnum = #graph,
      parent = tree.parent,
    }

    return true
  end

  for _, n in ipairs(tree.children) do
    if draw(n, graph, line2seq, other_info, seq, tree.indent) then
      return true
    end
  end
  return false
end

---@param tree UndoTreeNode
---@param graph string[]
---@param line2seq integer[]
---@param other_info OtherInfo[]
---@param last_seq integer
local function gen_graph(tree, graph, line2seq, other_info, last_seq)
  local cur_seq = 1
  while cur_seq <= last_seq do
    draw(tree, graph, line2seq, other_info, cur_seq, 0)
    cur_seq = cur_seq + 1
  end
end

---@class UndoTree
---@field char_graph? string[]
---@field line2seq? integer[]
---@field seq2line? integer[]
---@field seq2parent? (integer|nil)[]
---@field seq_last? integer
---@field seq_cur? integer
---@field seq_cur_bak? integer
local Undotree = {}

function Undotree.new()
  local obj = setmetatable({}, { __index = Undotree })
  obj:reset()

  return obj
end

---@param self UndoTree
function Undotree:reset()
  self.char_graph = {}
  self.line2seq = {}
  self.seq2line = {}
  self.seq2parent = {}

  self.seq_last = -1
  self.seq_cur = -1
  self.seq_cur_bak = -1
end

---@param self UndoTree
---@return boolean
function Undotree:gen_graph_tree()
  local undo_tree = vim.fn.undotree()

  self.seq_cur_bak = self.seq_cur
  self.seq_cur = undo_tree.seq_cur

  if self.seq_last == undo_tree.seq_last then
    return false
  end

  self:reset()
  self.seq_cur = undo_tree.seq_cur
  self.seq_last = undo_tree.seq_last

  local normal_tree = Node.new(0, nil, nil)
  local graph = { "*" }
  local line2seq = { 0 }
  local other_info = { [0] = { lnum = 1 } }

  parse_entries(undo_tree.entries, normal_tree)
  gen_indentions(normal_tree, 0)
  gen_graph(normal_tree, graph, line2seq, other_info, undo_tree.seq_last)

  self.seq2line[0] = #graph
  self.line2seq[#graph] = 0
  self.seq2parent[0] = nil
  graph[1] = graph[1] .. string.rep(" ", 4) .. "(Original)"

  for i = 2, self.seq2line[0] do
    if line2seq[i] ~= nil then
      local seq = line2seq[i]
      self.seq2line[seq] = #graph - i + 1
      self.line2seq[#graph - i + 1] = seq
      self.seq2parent[seq] = other_info[seq].parent

      graph[i] = graph[i]
        .. string.rep(" ", 4)
        .. seq
        .. (other_info[seq].save and " s " or "   ")
        .. time_ago(other_info[seq].time)
    end
  end

  self.char_graph = conf.reverse_table(graph)
  return true
end

return Undotree

-- vim:ts=2:sts=2:sw=2:et:ai:si:sta:
