local cfg = require("undotree.config").common

local _M = {}

--- @class SeqNode
--- @field seq integer
--- @field parent_seq integer
--- @field time integer
--- @field save boolean

--- @class AsciiGraphCell
--- @field col integer
--- @field char string single character '*' '|' '/' '\' '-'

--- @alias AsciiGraphLine AsciiGraphCell[]

--- @class Line2Seq
--- @field seq_node SeqNode?
--- @field graph_line AsciiGraphLine  it will be cleared after generate the real ascii graph

--- @alias Seq2Line integer[]

--- @param rt_ctx table runtime_ctx
--- @return string[]?  ascii graph   nil: not parsed
_M.parse_undotree = function(rt_ctx)
    local tree_ctx = vim.fn.undotree(rt_ctx.bufnr)

    if tree_ctx.seq_last == rt_ctx.max_seq then
        return nil
    end

    rt_ctx.max_seq = tree_ctx.seq_last
    rt_ctx.cur_seq = tree_ctx.seq_cur

    if type(cfg.parser) == "string" and cfg.parser == "legacy" then
        return require("undotree.parser.legacy").parse(rt_ctx, tree_ctx.entries)
    else
        return require("undotree.parser.compact").parse(rt_ctx, tree_ctx.entries)
    end
end

return _M
