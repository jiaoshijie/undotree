local _M = {}

function _M.contains(table, item)
  for _, v in ipairs(table) do
    if v == item then
      return true
    end
  end
  return false
end

function _M.reverse_table(input, output)
  -- NOTE: `output` must be a empty table
  for i = #input, 1, -1 do
    table.insert(output, input[i])
  end
end

function _M.setKeybinds(coll)
  local actions = require("undotree.action")
  local auCmd = vim.api.nvim_create_autocmd
  local km = vim.keymap.set

  for ft, keybinds in pairs(coll.keymaps) do
    auCmd("FileType", {
        pattern = ft,
        callback = function(ev)
            for k, v in pairs(keybinds) do
                km("n", k, function()
                    actions[v](coll)
                end, { noremap = true, silent = true, buffer = ev.buf })
            end
        end,
    })
  end
end


return _M
