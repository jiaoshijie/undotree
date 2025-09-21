---@class UndoTreeConfig
local M = {}

---@param T table
---@return table T
function M.reverse_table(T)
  if vim.fn.has("nvim-0.11") == 1 then
    vim.validate("T", T, "table", false)
  else
    vim.validate({ T = { T, "table" } })
  end

  local len = #T
  for i = 1, math.floor(len / 2), 1 do
    T[i], T[len - i + 1] = T[len - i + 1], T[i]
  end

  return T
end

return M

-- vim:ts=2:sts=2:sw=2:et:ai:si:sta:
