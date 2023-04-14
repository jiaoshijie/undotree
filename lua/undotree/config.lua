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

return _M
