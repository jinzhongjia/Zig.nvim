local M = {}

local version = "0.1.0"

-- return Zig.nvim version
M.version = function()
    return version
end

-- generate command description
--- @param desc string
--- @return string
M.command_desc = function(desc)
    return string.format("[Zig]: %s", desc)
end

---@generic T : any
---@param tbl T[]
---@param start_idx? number
---@param end_idx? number
---@return T[]
M.tbl_slice = function(tbl, start_idx, end_idx)
    local ret = {}
    if not start_idx then
        start_idx = 1
    end
    if not end_idx then
        end_idx = #tbl
    end
    for i = start_idx, end_idx - 1 do
        table.insert(ret, tbl[i])
    end
    return ret
end

return M
