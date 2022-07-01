local _M = {}

function _M.contains(table, item)
  for _, v in ipairs(table) do
    if v == item then
      return true
    end
  end
  return false
end

return _M
