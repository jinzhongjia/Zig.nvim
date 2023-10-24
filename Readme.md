One neovim plugin for `zig`

now, supported features:

- zls manager(install update uninstall) and automatic configuration
- zig fmt
- zig build
- zig version

I am currently developing under neovim nightly and have not tested its stability in 0.10

Usags:

Just install this plugin with your plugin manager, and then refer below:

```
local zig = require("Zig")
zig.setup({
-- config of plugin
})
```

Default config:
```lua
--- @type zig_zls_config
local default_zls_config = {
    enable = true,
    auto_install = true,
    path = string.format("%s/%s", default_data_path, "zls"),
    build_mode = "ReleaseSafe",
    lspconfig_opt = {},-- Just pass in the parameters as you normally do when configuring lspconfig.
    enable_lspconfig = false, -- When false, only zls will be added to neovim's environment variables
}

--- @type zig_config
local default_config = {
    filetype = true,
    fmt = true,
    build = true,
    zls = default_zls_config,
}
```
