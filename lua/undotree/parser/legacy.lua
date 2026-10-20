local kit = require("undotree.kit")
local _M = {}

local goc = function(t, i)
    t[i] = t[i] or { graph_line = {} }
    return t[i]
end

--- @return integer
local parse = function(stack, line2seq)
    local top_node = kit.stack_pop(stack)
    local max_col = 1

    while top_node do
        local root, lnum = top_node.node, top_node.lnum
        local col = top_node.col or max_col + 2
        local pctx = top_node.parent_ctx

        if pctx then
            for idx = pctx.col + 1, col do
                table.insert(pctx.line, { col = idx, char = idx == col and "+" or "-" })
            end
            pctx.col = col
        end

        local g_line = goc(line2seq, lnum).graph_line

        if root.seq - root.parent_seq > 1 then
            for _ = 1, root.seq - root.parent_seq - 1 do
                table.insert(g_line, { col = col, char = "|" })
                lnum = lnum + 1
                g_line = goc(line2seq, lnum).graph_line
            end
        end
        line2seq[lnum].seq_node = root
        table.insert(g_line, { col = col, char = "*" })
        max_col = col

        if root.children then
            local ctx = { line = g_line, col = col }
            for idx = #root.children, 1, -1 do
                kit.stack_push(stack, {
                    node = root.children[idx],
                    lnum = lnum + 1,
                    col = idx == 1 and col or nil,
                    parent_ctx = ctx,
                })
            end
            -- NOTE: clear no longer used field
            root.children = nil
        end

        top_node = kit.stack_pop(stack)
    end

    return max_col
end

--- @param rt_ctx table runtime_ctx
--- @param root UndoTree
--- @return integer
_M.parse = function(rt_ctx, root)
    local line2seq = {} --- @type Line2Seq
    local stack = {}

    kit.stack_push(stack, {
        node = root,
        lnum = 1,
        col = 1,
        parent_ctx = nil,
    })
    local max_col = parse(stack, line2seq)

    rt_ctx.line2seq = kit.reverse_list(line2seq)
    return max_col
end

return _M
