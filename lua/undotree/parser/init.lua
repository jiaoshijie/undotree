local cfg = require("undotree.config").common
local kit = require("undotree.kit")
local fmt = string.format
local rep = string.rep

local _M = {}

--- @class SeqNodeStat
--- @field time integer
--- @field save boolean

--- @class SeqNode
--- @field seq integer
--- @field parent_seq integer
--- @field stat SeqNodeStat?
--- @field children SeqNode[]?

--- @alias UndoTree SeqNode

--- @class AsciiGraphCell
--- @field col integer
--- @field char string single character '*' '|' '/' '\' '-' '+'
-- '*' '|' '+' only at odd col, '/' '\' '-' only at even col

--- @alias AsciiGraphLine AsciiGraphCell[]?

--- @class SeqLine
--- @field seq_node SeqNode?
--- @field graph_line AsciiGraphLine  it will be cleared after generate the real ascii graph
--- @field is_branch boolean?   ture: is a merge/split line, nil or false: is a node line

--- @alias Line2Seq SeqLine[]
--- @alias Seq2Line integer[]

-------------------------------------------------------------------------------

local minimum_seq = math.huge

--- @param seq integer
--- @param pseq integer
--- @param time integer
--- @param save integer?
--- @return SeqNode
local new_seq_node = function(seq, pseq, time, save)
    return {
        seq = seq,
        parent_seq = pseq,
        stat = {
            time = time,
            save = save and true or false,
        }
    }
end

local insert_seq_node = function(t, n)
    if n.seq < minimum_seq then minimum_seq = n.seq end

    for i, v in ipairs(t) do
        if v.seq < n.seq then
            table.insert(t, i, n)
            return
        end
    end
    table.insert(t, n)
end

local function gen_undotree_recursively(root, entries)
    for _, n in ipairs(entries) do
        root.children = root.children or {}
        if n.alt then
            gen_undotree_recursively(root, n.alt)
        end
        local new_node = new_seq_node(n.seq, root.seq, n.time, n.save)

        insert_seq_node(root.children, new_node)

        root = new_node
    end
end

local gen_ascii_graph = function(rt_ctx, max_col)
    local line2seq = rt_ctx.line2seq
    local seq2line = {}
    local graph = {}
    for lnum, v in ipairs(line2seq) do
        local line = ""
        local col = 1
        for _, c in ipairs(v.graph_line) do
            if col ~= c.col then
                assert(c.col > col)
                line = line .. string.rep(' ', c.col - col)
                col = c.col
            end

            line = line .. c.char
            col = col + 1
        end
        -- NOTE: clear members that no longer be used
        v.graph_line = nil
        v.is_branch = nil

        if v.seq_node then
            seq2line[v.seq_node.seq] = lnum
            if v.seq_node.seq ~= minimum_seq then
                line = fmt("%s  %s%d%s (%s)", line, rep(" ", max_col - #line),
                v.seq_node.seq,
                v.seq_node.stat.save and " s" or "",
                kit.time_ago(v.seq_node.stat.time))
            else
                line = fmt("%s  %s%d (Orig)", line, rep(" ", max_col - #line), minimum_seq)
            end
            -- NOTE: clear member that no longer be used
            v.seq_node.stat = nil
        end

        table.insert(graph, line)
    end
    rt_ctx.seq2line = seq2line

    return graph
end

--- @param rt_ctx table runtime_ctx
--- @return string[]?  ascii graph   nil: not parsed
_M.parse_undotree = function(rt_ctx)
    local tree_ctx = vim.fn.undotree(rt_ctx.target_bufnr)

    if tree_ctx.seq_last == rt_ctx.max_seq and #tree_ctx.entries ~= 0 then
        return nil
    end

    rt_ctx.max_seq = tree_ctx.seq_last
    rt_ctx.cur_seq = #tree_ctx.entries ~= 0 and tree_ctx.seq_cur or 0
    rt_ctx.line2seq = nil
    rt_ctx.seq2line = nil

    local root = new_seq_node(0, -1, -1, nil)
    minimum_seq = math.huge
    gen_undotree_recursively(root, tree_ctx.entries)
    minimum_seq = minimum_seq == math.huge and 0 or minimum_seq - 1

    if minimum_seq ~= 0 then
        -- NOTE: fix the undo nodes exceed the `undolevels` situation
        root.seq = minimum_seq
        root.parent_seq = root.seq - 1
        if root.children then
            for _, child in next, root.children do
                child.parent_seq = root.seq
            end
        end
    end

    local max_col
    if type(cfg.parser) == "string" and cfg.parser == "legacy" then
        max_col = require("undotree.parser.legacy").parse(rt_ctx, root)
    else
        max_col = require("undotree.parser.compact").parse(rt_ctx, root)
    end

    return gen_ascii_graph(rt_ctx, max_col)
end

return _M
