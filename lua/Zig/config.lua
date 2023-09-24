local lib_notify = require("Zig.lib.notify")

--- @type zig_config
local default_config = {
    filetype = true,
    fmt = true,
    build = true,
}

-- Prevent plugins from being initialized multiple times
local is_already_init = false

local M = {}

--- @type zig_config
M.options = {}

-- setup Zig.nvim plugin
--- @param config zig_config?
M.setup = function(config)
    -- check plugin whether has initialized
    if is_already_init then
        lib_notify.Warn("you have already initialized the plugin config!")
        return
    end

    config = config or {}
    M.options = vim.tbl_deep_extend("force", default_config, config)
    is_already_init = true
end

return M
