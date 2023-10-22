local uv = vim.uv
local M = {}

local lib_async = require("Zig.lib.async")
local lib_notify = require("Zig.lib.notify")

local version = "0.1.0"

local is_win = vim.fn.has("win32")

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
    lib_async.spawn("zig", {
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

--- @param path string
--- @param callback function?
M.mkdir = function(path, callback)
    if M.dir_exists(path) then
        if callback then
            callback()
        end
        return
    end
    uv.fs_mkdir(path, 493, function(err_1, _)
        if err_1 then
            vim.schedule(function()
                lib_notify.Warn(
                    string.format("create directory %s fails", path)
                )
            end)
            return
        end
        if callback then
            callback()
        end
    end)
end

--- @param path string
--- @param new_path string
--- @param callback function?
M.symlink = function(path, new_path, callback)
    uv.fs_symlink(path, new_path, function(err, _)
        if err then
            vim.schedule(function()
                lib_notify.Warn(
                    string.format("symlink %s to %s fails", path, new_path)
                )
            end)

            return
        end
        if callback then
            callback()
        end
    end)
end

--- @param path string
--- @param callback fun(param:uv.aliases.fs_stat_table|nil)
function M.fstat(path, callback)
    uv.fs_open(path, "r", 438, function(err, fd)
        assert(not err, err)
        if fd then
            uv.fs_fstat(fd, function(err_n, stat)
                assert(not err_n, err_n)
                uv.fs_close(fd)
                callback(stat)
            end)
        else
            callback(nil)
        end
    end)
end

--- @param path string
--- @param callback fun(res:boolean)
M.dir_exists = function(path, callback)
    M.fstat(path, function(param)
        if param then
            callback(param.type == "directory")
        else
            callback(false)
        end
    end)
end

--- @param path string
--- @param callback fun(res:boolean)
M.file_exists = function(path, callback)
    M.fstat(path, function(param)
        if param then
            callback(param.type == "file")
        else
            callback(false)
        end
    end)
end

--- @return boolean
M.is_win = function()
    return is_win == 1
end

--- @param path string
--- @param callback fun(res:boolean)
M.delete_file = function(path, callback)
    M.file_exists(path, function(res)
        if res then
            callback(vim.fn.delete(path) == 0)
        else
            callback(true)
        end
    end)
end

--- @param path string
--- @param callback fun(res:boolean)
M.delete_dir = function(path, callback)
    M.dir_exists(path, function(res)
        if res then
            callback(vim.fn.delete(path, "rf") == 0)
        else
            callback(true)
        end
    end)
end

return M
