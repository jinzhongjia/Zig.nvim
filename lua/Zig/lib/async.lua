local uv = vim.uv

local M = {}

--- @param path string
--- @param options uv.spawn.options
--- @param on_exit uv.spawn.on_exit?
--- @param on_out uv.read_start.callback?
--- @param on_err uv.read_start.callback?
M.spawn = function(path, options, on_exit, on_out, on_err)
    local handle, pid = uv.spawn(path, options, on_exit)

    if options.stdio and options.stdio[2] and on_out then
        -- read stdout
        ---@diagnostic disable-next-line: param-type-mismatch
        uv.read_start(options.stdio[2], on_out)
    end

    if options.stdio and options.stdio[3] and on_err then
        -- read stderr
        ---@diagnostic disable-next-line: param-type-mismatch
        uv.read_start(options.stdio[3], on_err)
    end

    return { handle = handle, pid = pid }
end

return M
