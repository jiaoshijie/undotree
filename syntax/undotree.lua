vim.cmd([[
syn match UndotreeFirstNode 'Original'
syn match UndotreeNode '\zs\*\ze'
syn match UndotreeSeq ' \zs\d\+\ze '
syn match UndotreeCurrent '>\d\+<'
syn match UndotreeTimeStamp '(.*)$'
syn match UndotreeSaved ' \zss\ze '
syn match UndotreeBranch '[|-]'
]])

-- vim:ts=2:sts=2:sw=2:et:ai:si:sta:
