local uv = vim.uv
local lib_async = require("Zig.lib.async")
local lib_notify = require("Zig.lib.notify")
local M = {}

--- @param url string
--- @param path string
--- @param callback fun()
M.download_file = function(url, path, callback)
    local errout = uv.new_pipe()
    ---@diagnostic disable-next-line: missing-fields
    lib_async.spawn("curl", {
        args = {
            "--create-dirs",
            "-s",
            "-o",
            path,
            url,
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
        else
            vim.schedule(function()
                lib_notify.Warn("sorry, Some errors occurred in curl")
            end)
        end
    end)

    ---@diagnostic disable-next-line: param-type-mismatch
    uv.read_start(errout, function(err, data)
        assert(not err, err)
        if data then
            vim.schedule(function()
                lib_notify.Warn(
                    string.format("curl download failed, err is %s", data)
                )
            end)
        end
    end)
end

return M
