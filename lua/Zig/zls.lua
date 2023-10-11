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

local command_key = "zls"

local build_arg = function()
    return string.format("-Doptimize=%s", config.options.zls.build_mode)
end

--- @param str string
local function echo_ok(str)
    vim.schedule(function()
        api.nvim_echo({
            { "Zig.nvim:", "" },
            { " ", "" },
            { str, "DiagnosticInfo" },
            { " ", "" },
            { "OK!", "DiagnosticOk" },
        }, false, {}) -- code
    end)
end

M.init = function()
    if not config.options.build then
        return
    end

    if is_initialized then
        return
    end

    is_initialized = true

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
    if lib_util.dir_exists(config.options.zls.path) then
        if vim.fn.delete(config.options.zls.path, "rf") ~= 0 then
            lib_notify.Warn("Delete the existing file failed")
            return
        end
    end

    local link_zls = function()
        lib_util.mkdir(get_bin_dir(), function()
            lib_util.symlink(
                string.format("%s/zig-out/bin/zls", config.options.zls.path),
                get_bin(),
                function()
                    echo_ok("link zls")
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
                build_arg(),
            },
            stdio = {
                nil,
                nil,
                ---@diagnostic disable-next-line: assign-type-mismatch
                errout,
            },
        }, function(code, _)
            if code == 0 then
                echo_ok("build zls")
                link_zls()
            else
                vim.schedule(function()
                    lib_notify.Warn("build zls fails, %s")
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

        echo_ok("clone zlg")
        build_zls()
    end)
end

M.update = function()
    if not lib_util.dir_exists(config.options.zls.path) then
        M.install()
        return
    end

    local build_zls = function()
        local errout = uv.new_pipe()
        ---@diagnostic disable-next-line: missing-fields
        lib_async.spawn("zig", {
            cwd = config.options.zls.path,
            args = {
                "build",
                build_arg(),
            },
            stdio = {
                nil,
                nil,
                ---@diagnostic disable-next-line: assign-type-mismatch
                errout,
            },
        }, function(code, _)
            if code == 0 then
                echo_ok("update zls")
            else
                vim.schedule(function()
                    lib_notify.Warn("build zls fails, %s")
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
        cwd = config.options.zls.path,
        args = {
            "pull",
        },
    }, function(code, signal)
        if code ~= 0 then
            vim.schedule(function()
                lib_notify.Warn("git pull zls fails, %s")
            end)
            return
        end

        echo_ok("pull zlg")
        build_zls()
    end)
end

-- uninstall zls
-- this will delete all files about zls
M.uninstall = function()
    if vim.fn.delete(config.options.zls.path, "rf") ~= 0 then
        lib_notify.Warn("delete zls clone dir fails")
        return
    end
    if vim.fn.delete(get_bin_dir(), "rf") ~= 0 then
        lib_notify.Warn("delete zls bin dir fails")
        return
    end
end

return M
