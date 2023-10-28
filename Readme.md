One neovim plugin for `zig`

now, supported features:

- zls manager(install update uninstall) and automatic configuration
- zig fmt
- zig build
- zig version

I am currently developing under neovim nightly and have not tested its stability in 0.10

Usags:

you nedd `curl` for download precompile binary.

Just install this plugin with your plugin manager, and then refer below:

```lua
local zig = require("Zig")
zig.setup({
-- config of plugin
})
```

Default config:
```lua
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
    auto_install = true, -- Now this is not working
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
```
