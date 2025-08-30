local conf = require('undotree.config')

local function time_ago(ptime)
  local mf, sec = math.floor, vim.fn.localtime() - ptime

  local mft

  if sec < 60 then
    mft = mf(sec)
    return '(' .. mft .. (mft > 1 and ' secs ago)' or ' sec ago)')
  elseif sec < 3600 then
    mft = mf(sec / 60)
    return '(' .. mft .. (mft > 1 and ' mins ago)' or ' sec ago)')
  elseif sec < 86400 then
    mft = mf(sec / 3600)
    return '(' .. mft .. (mft > 1 and ' hours ago)' or ' hour ago)')
  end

  mft = mf(sec / 86400)
  return '(' .. mft .. (mft > 1 and ' days ago)' or ' day ago)')
end

---@class UndoTreeNode
local node = {}

function node:new(seq, time, save)
  return { seq = seq, time = time, save = save, children = {} }
end

local function parse_entries(input, output)
  if vim.tbl_isempty(input) then
    return
  end

  for _, n in ipairs(input) do
    local new_node = node:new(n.seq, n.time, n.save)
    if n.alt ~= nil then
      parse_entries(n.alt, output)
    end
    table.insert(output.children, new_node)
    output = new_node
  end
end

local function gen_indentions(tree, indent)
  tree.indent = indent

  local ind = tree.indent

  for i, n in ipairs(tree.children) do
    if i ~= 1 then ind = ind + 1 end
    n.parent = tree.seq
    ind = gen_indentions(n, ind)
  end
  return ind
end

local function set_line(graph, index, char, indent)
  local line_len = string.len(graph[index])
  if line_len >= indent * 2 + 1 then
    graph[index] = graph[index]:sub(1, indent * 2) .. char .. graph[index]:sub(indent * 2 + 2)
  else
    graph[index] = graph[index] .. string.rep(" ", indent * 2 - line_len) .. char
  end
end


local function draw(tree, graph, line2seq, other_info, seq, parent_ind)
  if tree.seq == seq then
    local parent_lnum = other_info[tree.parent].lnum
    local parent_line_len = string.len(graph[parent_lnum])

    if parent_line_len < tree.indent * 2 + 1 then
      graph[parent_lnum] = graph[parent_lnum]
        .. string.rep("-", tree.indent * 2 + 1 - string.len(graph[parent_lnum]))
    elseif parent_line_len > tree.indent * 2 + 1 then
      graph[parent_lnum] = graph[parent_lnum]:sub(1, parent_ind * 2 + 1)
        .. string.rep("-", (tree.indent - parent_ind) * 2)
        .. graph[parent_lnum]:sub(tree.indent * 2 + 2)
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
    other_info[seq] = { save = tree.save, time = tree.time, lnum = #graph, parent = tree.parent }
    return true
  end

  for _, n in ipairs(tree.children) do
    if draw(n, graph, line2seq, other_info, seq, tree.indent) then
      return true
    end
  end
  return false
end

local function gen_graph(tree, graph, line2seq, other_info, last_seq)
  local cur_seq = 1
  while cur_seq <= last_seq do
    draw(tree, graph, line2seq, other_info, cur_seq, 0)
    cur_seq = cur_seq + 1
  end
end

---@class UndoTree
local Undotree = {}

function Undotree:new()
  local obj = setmetatable({
    char_graph = {},
    line2seq = {},
    seq2line = {},
    seq2parent = {},
    seq_last = -1,
    seq_cur = -1,
    seq_cur_bak = -1,
  }, { __index = Undotree })
  return obj
end

function Undotree:reset()
  self.char_graph = {}
  self.line2seq = {}
  self.seq2line = {}
  self.seq2parent = {}

  self.seq_last = -1
  self.seq_cur = -1
  self.seq_cur_bak = -1
end

function Undotree:gen_graph_tree()
  local undo_tree = vim.fn.undotree()

  self.seq_cur_bak, self.seq_cur = self.seq_cur, undo_tree.seq_cur

  if self.seq_last == undo_tree.seq_last then
    return false
  end

  self:reset()
  self.seq_cur, self.seq_last = undo_tree.seq_cur, undo_tree.seq_last

  local normal_tree = node:new(0, nil, nil)
  local graph, line2seq, other_info = { "*" }, { 0 }, { [0] = { lnum = 1 } }

  parse_entries(undo_tree.entries, normal_tree)
  gen_indentions(normal_tree, 0)
  gen_graph(normal_tree, graph, line2seq, other_info, undo_tree.seq_last)

  local graph_len = #graph

  self.seq2line[0], self.line2seq[graph_len] = graph_len, 0
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
