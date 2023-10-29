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

--- @param callback fun(version: { majro: string, minor: string, patch: string, prerelease: string, build: string, dev: boolean })
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
                    --- @type string
                    build = parse.build,
                    --- @type string
                    prerelease = parse.prerelease,
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
    M.dir_exists(path, function(res)
        if res then
            if callback then
                callback()
            end
        else
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
        if fd then
            uv.fs_fstat(fd, function(_, stat)
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
            vim.schedule(function()
                local tmp = vim.fn.delete(path) == 0
                callback(tmp)
            end)
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
            vim.schedule(function()
                callback(vim.fn.delete(path, "rf") == 0)
            end)
        else
            callback(true)
        end
    end)
end

--- @param path string
--- @param new_path string
--- @param callback fun()
M.copy_file = function(path, new_path, callback)
    local copy = function()
        uv.fs_copyfile(path, new_path, { ficlone = true }, function(_, success)
            if success then
                callback()
            else
                vim.schedule(function()
                    lib_notify.Error(
                        string.format("copy %s to %s failed", path, new_path)
                    )
                end)
            end
        end)
    end
    M.file_exists(new_path, function(res)
        if not res then
            copy()
        else
            M.delete_file(new_path, function(res_n)
                if res_n then
                    copy()
                else
                    vim.schedule(function()
                        lib_notify.Warn("delete existed file failed")
                    end)
                end
            end)
        end
    end)
end

--- @param path string
--- @param callback fun(res:boolean|nil)
M.chmod_exec = function(path, callback)
    local bit = require("bit")
    -- see chmod(2)
    local USR_EXEC = 0x40
    local GRP_EXEC = 0x8
    local ALL_EXEC = 0x1
    local EXEC = bit.bor(USR_EXEC, GRP_EXEC, ALL_EXEC)
    M.fstat(path, function(param)
        if param then
            if bit.band(param.mode, EXEC) ~= EXEC then
                local plus_exec = bit.bor(param.mode, EXEC)
                uv.fs_chmod(path, plus_exec, function(_, success)
                    callback(success)
                end)
            else
                callback(true)
            end
        else
            callback(false)
        end
    end)
end

return M
