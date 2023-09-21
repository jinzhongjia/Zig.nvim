local M = {}

-- setup Zig.nvim
--- @param  user_config zig_config?
M.setup = function(user_config)
    -- set config
    local config = require("Zig.config")
    config.setup(user_config)

    -- init command
    local command = require("Zig.command")
    command.init()

    -- init module
    local modules = require("Zig.modules")
    for _, module in pairs(modules) do
        module.init()
    end
end

return M
