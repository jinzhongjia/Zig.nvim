local api = vim.api
local config = require("Zig.config")
local lib_util = require("Zig.lib.util")

local M = {}

-- set filetype
local function set_filetype_zon()
    api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        pattern = "*.zon",
        callback = function()
            api.nvim_set_option_value("filetype", "zig", {
                buf = 0,
            })
        end,
        desc = lib_util.command_desc("set filetype automatically for .zon"),
    })
end

M.init = function()
    if config.options.filetype then
        set_filetype_zon()
    end
end

return M
