local lib_notify = require("Zig.lib.notify")

local default_data_path = vim.fn.stdpath("data") .. "/zig.nvim"

--- @type zig_zls_config
local default_zls_config = {
    enable = true,
    auto_install = true,
    path = string.format("%s/%s", default_data_path, "zls"),
}

--- @type zig_config
local default_config = {
    filetype = true,
    fmt = true,
    build = true,
    zls = default_zls_config,
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
