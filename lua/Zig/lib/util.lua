local M = {}

local version = "0.1.0"

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

return M
