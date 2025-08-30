local undotree = {}

local coll = require("undotree.collector")

function undotree.setup(opt)
  undotree.coll = coll:new(opt)
end

function undotree.open()
  undotree.coll:run()
end

function undotree.close()
  undotree.coll:close()
end

function undotree.toggle()
  if undotree.coll.src_bufnr then
    undotree.coll:close()
  else
    undotree.coll:run()
  end
end

return undotree

-- vim:ts=2:sts=2:sw=2:et:ai:si:sta:
