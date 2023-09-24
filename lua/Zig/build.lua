local uv = vim.uv

local command = require("Zig.command")
local config = require("Zig.config")
local lib_async = require("Zig.lib.async")
local lib_debug = require("Zig.lib.debug")
local lib_notify = require("Zig.lib.notify")
local lib_util = require("Zig.lib.util")

local M = {}

local command_key = "build"

-- whether this module is initialized
local is_initialized = false

M.init = function()
    if not config.options.fmt then
        return
    end

    if is_initialized then
        return
    end

    is_initialized = true

    command.register_command(command_key, M.run, {})
end

-- deinit for fmt
M.deinit = function()
    if not is_initialized then
        return
    end

    is_initialized = false

    command.unregister_command(command_key)
end

M.run = function()
    local root_path = lib_util.find_root()
    if not root_path then
        lib_notify.Info("not found build.zig!")
        return
    end
    local stdin = assert(uv.new_pipe())
    local stdout = assert(uv.new_pipe())
    local stderr = assert(uv.new_pipe())

    lib_async.spawn(
        "zig",
        ---@diagnostic disable-next-line: missing-fields
        {
            stdio = {
                ---@diagnostic disable-next-line: assign-type-mismatch
                stdin,
                ---@diagnostic disable-next-line: assign-type-mismatch
                stdout,
                ---@diagnostic disable-next-line: assign-type-mismatch
                stderr,
            },
            cwd = root_path,
            args = {
                "build",
            },
        },
        ---@diagnostic disable-next-line: unused-local
        function(code, signal)
            lib_debug.debug("finish build")
            local message
            if code == 0 then
                message = "build success!"
            else
                message = "build fail!"
            end
            vim.schedule(function()
                lib_notify.Info(message)
            end)
        end,
        function(err, data)
            assert(not err, err)
            lib_debug.debug(data)
            -- uv.shutdown(stdout)
        end,
        function(err, data)
            assert(not err, err)
            -- uv.shutdown(stderr)
        end
    )
    uv.shutdown(stdin)
end

return M
