local _M = {}

_M.setup = function(cfg)
    require("undotree.config").setup(cfg)
end

_M.open = function()
    require("undotree.runtime").open()
end

_M.close = function()
    require("undotree.runtime").close()
end

_M.toggle = function()
    local rt = require("undotree.runtime")
    if rt.is_visible_on_cur_tab() then
        rt.close()
    else
        if rt.is_opened() then
            rt.close()
        end
        rt.open()
    end
end

return _M
