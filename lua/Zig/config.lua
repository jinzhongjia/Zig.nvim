local lib_notify = require("Zig.lib.notify")

local default_data_path = vim.fn.stdpath("data") .. "/zig.nvim"

--- @type source_install
local default_source_install = {
    path = string.format("%s/%s", default_data_path, "zls"),
    build_mode = "ReleaseSafe",
    commit = "latest",
}

--- @type web_install
local default_web_install = {
    version = "latest",
}

--- @type zig_zls_config
local default_zls_config = {
    enable = true,
    auto_install = true,
    get_method = "web",
    source_install = default_source_install,
    web_install = default_web_install,
    enable_lspconfig = false,
    lspconfig_opt = {},
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
