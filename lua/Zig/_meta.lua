--- @class source_install
--- @field path string?  -- where zls source will be cloned 
--- @field build_mode ("Debug"|"ReleaseFast"|"ReleaseSafe"|"ReleaseSmall")? -- zls build mode, only for source_build
--- @field commit string? -- only for source_build

--- @class web_install
--- @field version (string|"latest"|"latestTagged")? -- which version will be installed

--- @class zig_zls_config
--- @field enable boolean? -- whether enable zls
--- @field auto_install boolean? -- whether automatically install zls TODO:
--- @field get_method ("source_build"|"web")?
--- @field source_install source_install? -- config for source_install
--- @field web_install web_install? -- config for web_install
--- @field enable_lspconfig boolean?-- whether enable lspconfig config
--- @field lspconfig_opt table? -- opt for lspconfig

--- @class zig_config
--- @field filetype boolean? whether enable filetype setting automatically
--- @field fmt boolean? whether enable fmt
--- @field build boolean? whether enable build
--- @field zls zig_zls_config? config for zls

-- @alias fmt_task {handle:uv.uv_process_t|uv_process_t,pid:integer,type:"file"|"buffer"}
