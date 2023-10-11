local uv, api = vim.uv, vim.api
local command = require("Zig.command")
local config = require("Zig.config")
local lib_async = require("Zig.lib.async")
local lib_notify = require("Zig.lib.notify")
local lib_util = require("Zig.lib.util")

local M = {}

local default_data_path = vim.fn.stdpath("data") .. "/zig.nvim"

-- whether this module is initialized
local is_initialized = false

local is_installed = false

local command_key = "zls"

M.init = function()
    if not config.options.build then
        return
    end

    if is_initialized then
        return
    end

    is_initialized = true

    if vim.fn.isdirectory(config.options.zls.path) ~= 0 then
        is_installed = true
    end

    command.register_command(
        command_key,
        M.run,
        { "install", "uninstall", "update" }
    )
end

M.deinit = function()
    if not is_initialized then
        return
    end

    is_initialized = false
    is_installed = false

    command.unregister_command(command_key)
end

local get_bin_dir = function()
    return string.format("%s/bin", default_data_path)
end

-- get zls bin
local get_bin = function()
    return string.format("%s/zls", get_bin_dir())
end

--- @param args string[]
M.run = function(args)
    if #args == 0 then
        lib_notify.Info("should pass a param")
        return
    end

    local param = args[1]
    if param == "install" then
        M.install()
    elseif param == "uninstall" then
        M.uninstall()
    elseif param == "update" then
        M.update()
    else
        lib_notify.Info("not recognize param")
    end
end

M.install = function()
    if vim.fn.isdirectory(config.options.zls.path) ~= 0 then
        uv.fs_rmdir(config.options.zls.path)
    end

    local link_zls = function()
        lib_util.mkdir(get_bin_dir(), function()
            lib_util.symlink(
                string.format("%s/zig-out/bin/zls", config.options.zls.path),
                get_bin(),
                function()
                    vim.schedule(function()
                        lib_notify.Info("install zls success!")
                    end)
                end
            )
        end)
    end

    local build_zls = function()
        local errout = uv.new_pipe()
        ---@diagnostic disable-next-line: missing-fields
        lib_async.spawn("zig", {
            cwd = config.options.zls.path,
            args = {
                "build",
                -- TODO: add build mode select
                "-Doptimize=ReleaseSafe",
            },
            stdio = {
                nil,
                nil,
                ---@diagnostic disable-next-line: assign-type-mismatch
                errout,
            },
        }, function(code, signal)
            if code == 0 then
                link_zls()
            else
                vim.schedule(function()
                    lib_notify.Warn("git clone zls fails, %s")
                end)
            end
        end)

        ---@diagnostic disable-next-line: param-type-mismatch
        uv.read_start(errout, function(err, data)
            assert(not err, err)
            if data then
                vim.schedule(function()
                    lib_notify.Warn(
                        string.format("compile zls fails. err is %s", data)
                    )
                end)
            end
        end)
    end

    ---@diagnostic disable-next-line: missing-fields
    lib_async.spawn("git", {
        args = {
            "clone",
            "--depth",
            "1",
            "https://github.com/zigtools/zls.git",
            config.options.zls.path,
        },
    }, function(code, signal)
        if code ~= 0 then
            vim.schedule(function()
                lib_notify.Warn("git clone zls fails, %s")
            end)
            return
        end
        build_zls()
    end)
end

M.update = function() end

M.uninstall = function() end

return M
