local kit = require("undotree.kit")
local _M = {}

local goc = function(t, i)
    t[i] = t[i] or { graph_line = {} }
    return t[i]
end

--- @return integer max_col
local function parse_recursively(root, line2seq, lnum, col)
    local g_line = goc(line2seq, lnum).graph_line

    if root.seq - root.parent_seq > 1 then
        for _ = 1, root.seq - root.parent_seq - 1 do
            table.insert(g_line, { col = col, char = '|' })
            lnum = lnum + 1
            g_line = goc(line2seq, lnum).graph_line
        end
    end
    line2seq[lnum].seq_node = root
    table.insert(g_line, { col = col, char = '*' })
    local max_col = col - 2

    if not root.children then return col end

    for _, node in ipairs(root.children) do
        max_col = max_col + 2
        for i = col + 1, max_col do
            table.insert(g_line, { col = i, char = i == max_col and '+' or '-' })
        end
        col = max_col

        max_col = parse_recursively(node, line2seq, lnum + 1, col)
    end

    root.children = nil

    return max_col
end

--- @param rt_ctx table runtime_ctx
--- @param root UndoTree
_M.parse = function(rt_ctx, root)
    local line2seq = {}  --- @type Line2Seq
    parse_recursively(root, line2seq, 1, 1)
    rt_ctx.line2seq = kit.reverse_table(line2seq)
end

return _M
