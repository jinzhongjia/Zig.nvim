local uv = vim.uv
local lib_async = require("Zig.lib.async")
local lib_notify = require("Zig.lib.notify")

local M = {}

--- @param path string
--- @param callback fun()
M.fetch = function(path, callback)
    local errout = uv.new_pipe()
    ---@diagnostic disable-next-line: missing-fields
    lib_async.spawn("git", {
        cwd = path,
        args = {
            "fetch",
        },
        stdio = {
            nil,
            nil,
            ---@diagnostic disable-next-line: assign-type-mismatch
            errout,
        },
    }, function(code, _)
        if code == 0 then
            callback()
        end
    end)
    ---@diagnostic disable-next-line: param-type-mismatch
    uv.read_start(errout, function(err, data)
        assert(not err, err)
        if data then
            vim.schedule(function()
                lib_notify.Warn(
                    string.format("git fetch failed, err is %s", data)
                )
            end)
        end
    end)
end

--- @param path string
--- @param callback fun(commit:string)
M.latest_origin_commit = function(path, callback)
    M.fetch(path, function()
        M.latest_commit(path, true, function(commit)
            callback(commit)
        end)
    end)
end

--- @param path string
--- @param origin boolean
--- @param callback fun(commit:string)
M.latest_commit = function(path, origin, callback)
    local errout = uv.new_pipe()
    local out = uv.new_pipe()
    local args = {
        "log",
        '--pretty=format:"%h"',
        "-1",
    }
    if origin then
        table.insert(args, "origin")
    end
    ---@diagnostic disable-next-line: missing-fields
    lib_async.spawn("git", {
        cwd = path,
        args = args,
        stdio = {
            nil,
            ---@diagnostic disable-next-line: assign-type-mismatch
            out,
            ---@diagnostic disable-next-line: assign-type-mismatch
            errout,
        },
    }, function(_, _) end)
    ---@diagnostic disable-next-line: param-type-mismatch
    uv.read_start(errout, function(err, data)
        assert(not err, err)
        if data then
            vim.schedule(function()
                lib_notify.Warn(
                    string.format("git get last commit failed, err is %s", data)
                )
            end)
        end
    end)

    ---@diagnostic disable-next-line: param-type-mismatch
    uv.read_start(out, function(err, data)
        assert(not err, err)
        if data then
            callback(data)
        end
    end)
end

--- @param path string
--- @param callback fun()
M.pull = function(path, callback)
    local errout = uv.new_pipe()
    ---@diagnostic disable-next-line: missing-fields
    lib_async.spawn("git", {
        cwd = path,
        args = {
            "pull",
        },
        stdio = {
            nil,
            nil,
            ---@diagnostic disable-next-line: assign-type-mismatch
            errout,
        },
    }, function(code, _)
        if code == 0 then
            callback()
        end
    end)
    ---@diagnostic disable-next-line: param-type-mismatch
    uv.read_start(errout, function(err, data)
        assert(not err, err)
        if data then
            vim.schedule(function()
                lib_notify.Warn(
                    string.format("git pull failed, err is %s", data)
                )
            end)
        end
    end)
end

--- @param path string
--- @param callback fun()
M.clone = function(url, path, callback)
    local errout = uv.new_pipe()
    ---@diagnostic disable-next-line: missing-fields
    lib_async.spawn("git", {
        cwd = path,
        args = {
            "clone",
            "--depth",
            "1",
            url,
            path,
        },
        stdio = {
            nil,
            nil,
            ---@diagnostic disable-next-line: assign-type-mismatch
            errout,
        },
    }, function(code, _)
        if code == 0 then
            callback()
        end
    end)
    ---@diagnostic disable-next-line: param-type-mismatch
    uv.read_start(errout, function(err, data)
        assert(not err, err)
        if data then
            vim.schedule(function()
                lib_notify.Warn(
                    string.format("git clone failed, err is %s", data)
                )
            end)
        end
    end)
end

return M
