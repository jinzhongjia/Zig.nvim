local uv = vim.uv
local M = {}

local async = require("Zig.lib.async")

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
M.find_root = function()
    local path_list = vim.fs.find("build.zig", {
        upward = true,
        stop = vim.uv.os_homedir(),
        path = vim.uv.cwd(),
    })
    if #path_list == 0 then
        return nil
    end

    return vim.fs.dirname(path_list[1])
end

--- @param callback fun(version: { majro: string, minor: string, patch: string, dev: boolean })
M.get_zig_version = function(callback)
    local stdout = uv.new_pipe()
    ---@diagnostic disable-next-line: missing-fields
    async.spawn("zig", {
        args = { "version" },
        stdio = {
            nil,
            ---@diagnostic disable-next-line: assign-type-mismatch
            stdout,
            nil,
        },
    })
    ---@diagnostic disable-next-line: param-type-mismatch
    uv.read_start(stdout, function(err, data)
        assert(err == nil)
        if data then
            local parse = vim.version.parse(data, {})
            if parse then
                local version_data = {
                    --- @type string
                    majro = parse.major,
                    --- @type string
                    minor = parse.minor,
                    --- @type string
                    patch = parse.patch,
                    --- @type boolean
                    dev = string.find(parse.prerelease, "dev") ~= nil,
                }
                callback(version_data)
            end
        end
    end)
end

return M
