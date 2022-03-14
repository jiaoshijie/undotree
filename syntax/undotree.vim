syn match UndotreeFirstNode 'Original'
syn match UndotreeNode ' \zs\*\ze '
syn match UndotreeSeq ' \zs\d\+\ze '
syn match UndotreeCurrent '>\d\+<'
syn match UndotreeTimeStamp '(.*)$'
syn match UndotreeSaved ' \zss\ze '
syn match UndotreeBranch '[|/]'

hi def link UndotreeFirstNode Function
hi def link UndotreeNode Question
hi def link UndotreeSeq Comment
hi def link UndotreeCurrent Statement
hi def link UndotreeTimeStamp Function
hi def link UndotreeSaved Conceal
hi def link UndotreeBranch Constant

hi def link UndotreeDiffLine diffLine
hi def link UndotreeDiffAdded diffAdded
hi def link UndotreeDiffRemoved diffRemoved
