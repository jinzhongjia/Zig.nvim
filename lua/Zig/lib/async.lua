local uv = vim.uv
local lib_debug = require("Zig.lib.debug")

local M = {}

--- @param path string
--- @param options uv.spawn.options
--- @param on_exit  uv.spawn.on_exit
--- @param on_out uv.read_start.callback
--- @param on_err uv.read_start.callback
M.spawn = function(path, options, on_exit, on_out, on_err)
    local stdin = assert(uv.new_pipe())
    local stdout = assert(uv.new_pipe())
    local stderr = assert(uv.new_pipe())

    ---@diagnostic disable-next-line: assign-type-mismatch
    options.stdio = { stdin, stdout, stderr }

    -- local async = uv.new_async(function()
    local handle, pid = uv.spawn(path, options, on_exit)
    -- lib_debug.debug(uv.spawn(path, options, on_exit))
    -- lib_debug.debug("running")
    -- read stdout
    uv.read_start(stdout, on_out)
    -- read stderr
    uv.read_start(stderr, on_err)
    -- end)

    -- return stdin, async
    return stdin, { handle = handle, pid = pid }
end

return M
