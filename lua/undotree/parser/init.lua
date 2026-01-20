local cfg = require("undotree.config").common
local kit = require("undotree.kit")
local fmt = string.format

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

local gen_ascii_graph = function(rt_ctx)
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
        -- NOTE: clear members that will no longer be used
        v.graph_line = nil
        v.is_branch = nil

        if v.seq_node then
            seq2line[v.seq_node.seq] = lnum
            if v.seq_node.seq ~= 0 then
                line = fmt("%s    %d%s (%s)", line, v.seq_node.seq,
                v.seq_node.stat.save and " s" or "",
                kit.time_ago(v.seq_node.stat.time))
            else
                line = fmt("%s    0 (Original)", line)
            end
            -- NOTE: clear member that will no longer be used
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

    if tree_ctx.seq_last == rt_ctx.max_seq then
        return nil
    end

    rt_ctx.max_seq = tree_ctx.seq_last
    rt_ctx.cur_seq = tree_ctx.seq_cur
    rt_ctx.line2seq = nil
    rt_ctx.seq2line = nil

    local root = new_seq_node(0, -1, -1, nil)
    gen_undotree_recursively(root, tree_ctx.entries)

    if type(cfg.parser) == "string" and cfg.parser == "legacy" then
        require("undotree.parser.legacy").parse(rt_ctx, root)
    else
        require("undotree.parser.compact").parse(rt_ctx, root)
    end

    return gen_ascii_graph(rt_ctx)
end

return _M
