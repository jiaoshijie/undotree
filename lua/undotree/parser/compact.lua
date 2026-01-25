local kit = require("undotree.kit")
local _M = {}
local maximum_col = 0

local goc = function(t, i)
    t[i] = t[i] or { graph_line = {} }
    return t[i]
end

--- @param g_line AsciiGraphCell[]
--- @return integer
local get_max_col = function(g_line)
    return #g_line == 0 and -1 or g_line[#g_line].col
end

--- @param g_line AsciiGraphCell[]
--- @param col integer
--- @return integer
local adjust_branch_line = function(g_line, col)
    local cell = g_line[#g_line]
    if cell.char == "/" and (cell.col == col + 1 or cell.col == col - 1) then
        if cell.col ~= col + 1 then
            table.insert(g_line, { char = "/", col = col + 1 })
        end
        return col + 2
    elseif cell.char == "\\" then
        if cell.col ~= col - 1 then
            table.insert(g_line, { char = "\\", col = col - 1 })
        end
        return col - 2
    end

    if cell.col ~= col then
        table.insert(g_line, { char = "|", col = col })
    end
    return col
end

--- @param line2seq Line2Seq
--- @param lnum integer
--- @param col integer
--- @param is_merge boolean
--- @return integer
local new_branch_line = function(line2seq, lnum, col, is_merge)
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
            table.insert(newline.graph_line, { char = "|", col = pcol })
            pc = pc + 1
            cc = cc + 1
        elseif pcol > ccol then
            cc = cc + 1
        else -- pcol < ccol
            pc = pc + 1
        end
    end
    if is_merge then
        col = col - 2
        table.insert(newline.graph_line, { char = "\\", col = col + 1 })
    else -- fork
        col = col + 2
        table.insert(newline.graph_line, { char = "/", col = col - 1 })
    end
    table.insert(line2seq, lnum, newline)

    return col
end

--- @return integer  -- lnum
--- @return integer  -- col
local put_seq_node = function(node, line2seq, lnum, col, split)
    local s_line = goc(line2seq, lnum)
    local cur_col = get_max_col(s_line.graph_line)

    if s_line.is_branch then
        -- NOTE: It must be `\`, because I am the node will put `|/` here.
        -- below `\` and above `/` must already has a node
        if split then
            table.insert(s_line.graph_line, { char = "|", col = col })
        else
            assert(cur_col ~= col - 1) -- it must not belong to the previous branch
            col = adjust_branch_line(s_line.graph_line, col)
        end
        lnum = lnum + 1
    elseif split then
        col = new_branch_line(line2seq, lnum, col, false)
        lnum = lnum + 1
    elseif col - 2 > cur_col then -- check if can merge
        col = new_branch_line(line2seq, lnum, col, true)
        lnum = lnum + 1
    end

    s_line = goc(line2seq, lnum)
    table.insert(s_line.graph_line, { char = "*", col = col })
    s_line.seq_node = node

    return lnum, col
end

local function parse_recursively(root, line2seq, lnum, col, split)
    local distance = root.seq - root.parent_seq - 1
    while distance > 0 do
        local s_line = goc(line2seq, lnum)
        if s_line.is_branch then
            col = adjust_branch_line(s_line.graph_line, col)
        else
            local cur_col = get_max_col(s_line.graph_line)
            if col - 2 == cur_col then
                table.insert(s_line.graph_line, { char = "|", col = col })
            elseif col > cur_col then
                col = new_branch_line(line2seq, lnum, col, true)
                goto outer_end
            end
            -- NOTE: if col == cur_col do nothing, just follow the branch
            -- And there is no way cur_col bigger than col
            distance = distance - 1
        end
        ::outer_end::
        lnum = lnum + 1
    end

    lnum, col = put_seq_node(root, line2seq, lnum, col, split)

    -- NOTE: I know this will not get the true maximum column number,
    -- but put it here making the code more clean.
    if maximum_col < col then
        maximum_col = col
    end

    if not root.children then
        return
    end

    for i, node in ipairs(root.children) do
        parse_recursively(node, line2seq, lnum + 1, col, i ~= 1)
    end

    -- clear no longer used variable
    root.children = nil
end

--- @param rt_ctx table runtime_ctx
--- @param root UndoTree
_M.parse = function(rt_ctx, root)
    local line2seq = {} --- @type Line2Seq
    maximum_col = 0
    parse_recursively(root, line2seq, 1, 1, false)
    rt_ctx.line2seq = kit.reverse_table(line2seq)
    -- NOTE: `+ 2`: to fix the false maximum column number above
    return maximum_col + 2
end

return _M
