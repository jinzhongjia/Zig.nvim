local uv = vim.uv

local command = require("Zig.command")
local config = require("Zig.config")
local lib_async = require("Zig.lib.async")
local lib_notify = require("Zig.lib.notify")
local lib_util = require("Zig.lib.util")

local M = {}

local command_key = "build"

-- whether this module is initialized
local is_initialized = false

M.init = function()
    if not config.options.build then
        return
    end

    if is_initialized then
        return
    end

    is_initialized = true

    command.register_command(command_key, M.run, { "run", "test" })
end

-- deinit for fmt
M.deinit = function()
    if not is_initialized then
        return
    end

    is_initialized = false

    command.unregister_command(command_key)
end

--- @param args string[]
M.run = function(args)
    local root_path = lib_util.find_root()
    if not root_path then
        lib_notify.Info("not found build.zig!")
        return
    end

    local new_args = {}
    table.insert(new_args, "build")
    for _, arg in pairs(args) do
        table.insert(new_args, arg)
    end

    -- local stdin = assert(uv.new_pipe())
    local stdout = assert(uv.new_pipe())
    local stderr = assert(uv.new_pipe())

    lib_async.spawn(
        "zig",
        ---@diagnostic disable-next-line: missing-fields
        {
            stdio = {
                ---@diagnostic disable-next-line: assign-type-mismatch
                nil,
                ---@diagnostic disable-next-line: assign-type-mismatch
                stdout,
                ---@diagnostic disable-next-line: assign-type-mismatch
                stderr,
            },
            cwd = root_path,
            args = new_args,
        },
        ---@diagnostic disable-next-line: unused-local
        function(code, signal)
            local message
            if code == 0 then
                message = "build success!"
            else
                message = "build fail!"
            end
            vim.schedule(function()
                -- this will only notify when build fail or not more args
                if code ~= 0 or #args == 0 then
                    lib_notify.Info(message)
                end
            end)
            uv.shutdown(stdout)
            uv.shutdown(stderr)
        end,
        function(err, data)
            assert(not err, err)
            -- lib_debug.debug(data)
        end,
        function(err, data)
            assert(not err, err)
            -- lib_debug.debug(data)
        end
    )
    -- uv.shutdown(stdin)
end

return M
