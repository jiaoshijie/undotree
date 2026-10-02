vim.g.undotree_testing = true
local fmt = string.format

local eq = function(expected, actual)
    if not vim.deep_equal(expected, actual) then
        error(
            fmt(
                "\nexpected:\n%s\n\nactual:\n%s\n",
                table.concat(expected, "\n"),
                table.concat(actual, "\n")
            ),
            2
        )
    end
end

local parser = require("undotree.parser")
local cfg = require("undotree.config")

local script_dir = debug.getinfo(1, "S").source:gsub("^@", ""):match("(.*/)")
local case_dir = fmt("%s/cases", script_dir)

local iter = vim.fs.dir(case_dir, { depth = 1, follow = false })

for name, typ in iter do
    if typ ~= "file" then
        return
    end
    local case_file = fmt("%s/%s", case_dir, name)
    local lines = vim.fn.readfile(case_file)
    local undotree_history = vim.json.decode(lines[1])
    if type(undotree_history) ~= "table" then
        error(fmt("Invalid undotree history file %s", case_file), 2)
    end

    cfg.common.parser = "legacy"
    local end_line = tonumber(lines[2])
    if type(end_line) ~= "number" then
        error(fmt("Invalid undotree history file %s", case_file), 2)
    end

    eq(
        vim.list_slice(lines, 3, end_line),
        parser.parse_undotree({
            undotree_history = undotree_history,
        })
    )

    cfg.common.parser = "compact"
    local start_line = end_line + 2
    end_line = tonumber(lines[end_line + 1])
    if type(end_line) ~= "number" then
        error(fmt("Invalid undotree history file %s", case_file), 2)
    end
    eq(
        vim.list_slice(lines, start_line, end_line),
        parser.parse_undotree({
            undotree_history = undotree_history,
        })
    )
end
