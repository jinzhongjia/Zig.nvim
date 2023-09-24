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

-- try to find build.zig root path
M.find_root = function(buffer_id)
    local path_list = vim.fs.find("build.zig", {
        upward = true,
        stop = vim.uv.os_homedir(),
        path = vim.fs.dirname(vim.api.nvim_buf_get_name(buffer_id)),
    })
    if #path_list == 0 then
        return nil
    end
    return #path_list[1]
end

return M
