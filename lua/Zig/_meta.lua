--- @class zig_zls_config
--- @field enable boolean? -- whether enable zls
--- @field auto_install boolean? -- whether automatically install zls
--- @field path string? -- where zls will install
--- @field lspconfig_opt table? -- opt for lspconfig
--- @field enable_lspconfig boolean?-- whether enable lspconfig config
--- @field get_method ("source_build"|"web")?
--- @field build_mode ("Debug"|"ReleaseFast"|"ReleaseSafe"|"ReleaseSmall")? -- zls build mode, only for source_build
--- @field commit string? -- only for source_build
--- @field web_version string? -- only for web

--- @class zig_config
--- @field filetype boolean? whether enable filetype setting automatically
--- @field fmt boolean? whether enable fmt
--- @field build boolean? whether enable build
--- @field zls zig_zls_config? config for zls

-- @alias fmt_task {handle:uv.uv_process_t|uv_process_t,pid:integer,type:"file"|"buffer"}
