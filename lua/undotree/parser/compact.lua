local kit = require("undotree.kit")
local _M = {}

local goc = function(t, i)
    t[i] = t[i] or { graph_line = {} }
    return t[i]
end

--- @return integer
local shift_col_by_branch = function(g_line, col)
    local cell = g_line[#g_line]
    if cell.char == '/' then
        if cell.col == col + 1 or cell.col == col - 1 then
            if cell.col ~= col + 1 then
                table.insert(g_line, { char = '/', col = col + 1 })
            end
            return col + 2
        end
    elseif cell.char == '\\' then
        if cell.col ~= col - 1 then
            table.insert(g_line, { char = '\\', col = col - 1 })
        end
        return col - 2
    end
    -- |
    if cell.col ~= col then
        table.insert(g_line, { char = '|', col = col })
    end
    return col
end

local merge = function(line2seq, lnum, col)
    local newline = { is_branch = true, graph_line = {} }
    local p_line = goc(line2seq, lnum - 1).graph_line
    local p_len = #p_line
    local c_line = goc(line2seq, lnum).graph_line
    local c_len = #c_line

    local pc, cc = 1, 1
    while pc <= p_len and cc <= c_len do
        local pcol = p_line[pc].col
        local ccol = c_line[cc].col
        if pcol == ccol then
            table.insert(newline.graph_line, { char = '|', col = pcol })
            pc = pc + 1
            cc = cc + 1
        elseif pcol > ccol then
            cc = cc + 1
        else  -- pcol < ccol
            pc = pc + 1
        end
    end
    table.insert(newline.graph_line, { char = '\\', col = col + 1 })
    table.insert(line2seq, lnum, newline)
end

local fork = function(line2seq, lnum, col)
    local newline = { is_branch = true, graph_line = {} }
    local p_line = goc(line2seq, lnum - 1).graph_line
    local p_len = #p_line
    local c_line = goc(line2seq, lnum).graph_line
    local c_len = #c_line

    local pc, cc = 1, 1
    while pc <= p_len and cc <= c_len do
        local pcol = p_line[pc].col
        local ccol = c_line[cc].col
        if pcol == ccol then
            table.insert(newline.graph_line, { char = '|', col = pcol })
            pc = pc + 1
            cc = cc + 1
        elseif pcol > ccol then
            cc = cc + 1
        else  -- pcol < ccol
            pc = pc + 1
        end
    end
    table.insert(newline.graph_line, { char = '/', col = col - 1 })
    table.insert(line2seq, lnum, newline)
end

--- @return integer
--- @return integer
local insert_seqnode = function(node, line2seq, lnum, col, split)
    local s_line = goc(line2seq, lnum)
    if s_line.is_branch then
        if split then
            table.insert(s_line.graph_line, { char = '|', col = col })
        else
            local cell = s_line.graph_line[#s_line.graph_line]
            assert(cell.col ~= col - 1)
            table.insert(s_line.graph_line, { char = '\\', col = col - 1 })
            col = col - 2
        end
        lnum = lnum + 1
    elseif split then
        col = col + 2
        fork(line2seq, lnum, col)
        lnum = lnum + 1
    else
        -- TODO: check if can merge
        if col >= 3 then
            if #s_line.graph_line == 0
                or s_line.graph_line[#s_line.graph_line].col < col - 2 then
                col = col - 2
                merge(line2seq, lnum, col)
                lnum = lnum + 1
            end
        end
    end
    s_line = goc(line2seq, lnum)
    table.insert(s_line.graph_line, { char = '*', col = col })
    s_line.seq_node = node

    return col, lnum
end

local function parse_recursively(root, line2seq, lnum, col, split)
    local distance = root.seq - root.parent_seq - 1
    while distance > 0 do
        local s_line = goc(line2seq, lnum)
        if s_line.is_branch then
            col = shift_col_by_branch(s_line.graph_line, col)
        else
            if #s_line.graph_line == 0 then
                if col == 1 then
                    table.insert(s_line.graph_line, { char = '|', col = col })
                    goto inter_end
                end
                -- col is begger then 1, merge
                col = col - 2
                table.insert(s_line.graph_line, { char = '\\', col = col + 1 })
                s_line.is_branch = true
                goto outer_end
            else
                local cur_col = s_line.graph_line[#s_line.graph_line].col
                if cur_col == col then
                    goto inter_end
                elseif col - 2 == cur_col then
                    -- can not merge
                    table.insert(s_line.graph_line, { char = '|', col = col })
                else
                    assert(cur_col < col)
                    -- col is begger then cur_col, merge
                    col = col - 2
                    merge(line2seq, lnum, col)
                    goto outer_end
                end
            end
            ::inter_end::
            distance = distance - 1
        end
        ::outer_end::
        lnum = lnum + 1
    end

    col, lnum = insert_seqnode(root, line2seq, lnum, col, split)

    if not root.children then return end

    for i, node in ipairs(root.children) do
        parse_recursively(node, line2seq, lnum + 1, col, i ~= 1)
    end

    root.children = nil
end

--- @param rt_ctx table runtime_ctx
--- @param root UndoTree
_M.parse = function(rt_ctx, root)
    local line2seq = {}  --- @type Line2Seq
    parse_recursively(root, line2seq, 1, 1, false)
    rt_ctx.line2seq = kit.reverse_table(line2seq)
end

return _M
