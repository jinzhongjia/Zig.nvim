local uv, api = vim.uv, vim.api
local command = require("Zig.command")
local config = require("Zig.config")
local lib_async = require("Zig.lib.async")
local lib_debug = require("Zig.lib.debug")
local lib_git = require("Zig.lib.git")
local lib_notify = require("Zig.lib.notify")
local lib_util = require("Zig.lib.util")

local M = {}

local default_data_path = vim.fn.stdpath("data") .. "/zig.nvim"

-- whether this module is initialized
local is_initialized = false

local command_key = "zls"

local build_arg = function()
    return string.format("-Doptimize=%s", config.options.zls.build_mode)
end

--- @param str string
local function echo_ok(str)
    vim.schedule(function()
        api.nvim_echo({
            { "Zig.nvim:", "" },
            { " ", "" },
            { str, "DiagnosticInfo" },
            { " ", "" },
            { "OK!", "DiagnosticOk" },
        }, false, {}) -- code
    end)
end

local get_bin_dir = function()
    return string.format("%s/bin", default_data_path)
end

-- get zls bin
local get_bin = function()
    return string.format("%s/zls", get_bin_dir())
end

M.init = function()
    if not config.options.build then
        return
    end

    if is_initialized then
        return
    end

    is_initialized = true

    command.register_command(command_key, M.run, {
        ["install"] = {},
        ["uninstall"] = {},
        ["update"] = {
            ["force"] = {},
        },
    })

    lib_util.file_exists(get_bin(), function(res)
        if res then
            vim.schedule(function()
                do
                    -- in this scope
                    -- we will Try injecting neovim's environment variables
                    vim.env.PATH = string.format(
                        "%s%s%s",
                        vim.env.PATH,
                        lib_util.is_win() and ";" or ":",
                        get_bin_dir()
                    )
                end

                if config.options.zls.enable_lspconfig then
                    M.config_lspconfig()
                end
            end)
        end
    end)
end

M.deinit = function()
    if not is_initialized then
        return
    end

    is_initialized = false

    command.unregister_command(command_key)
end

--- @param args string[]
M.run = function(args)
    if #args == 0 then
        lib_notify.Info("should pass a param")
        return
    end

    local param = args[1]
    if param == "install" then
        M.install()
    elseif param == "uninstall" then
        M.uninstall()
    elseif param == "update" then
        if args[2] == "force" then
            M.update(true)
        else
            M.update()
        end
    else
        lib_notify.Info("not recognize param")
    end
end

M.install = function()
    lib_util.delete_file(get_bin(), function(res)
        if not res then
            vim.schedule(function()
                lib_notify.Warn("delete the existing zls bin file fails")
            end)
            return
        end

        lib_util.delete_dir(config.options.zls.path, function(res_n)
            if not res_n then
                vim.schedule(function()
                    lib_notify.Warn("delete existing zls git dir fails")
                end)
                return
            end

            local link_zls = function()
                lib_util.mkdir(get_bin_dir(), function()
                    lib_util.symlink(
                        string.format(
                            "%s/zig-out/bin/zls",
                            config.options.zls.path
                        ),
                        get_bin(),
                        function()
                            echo_ok("link zls")
                        end
                    )
                end)
            end

            local build_zls = function()
                local errout = uv.new_pipe()
                ---@diagnostic disable-next-line: missing-fields
                lib_async.spawn("zig", {
                    cwd = config.options.zls.path,
                    args = {
                        "build",
                        build_arg(),
                    },
                    stdio = {
                        nil,
                        nil,
                        ---@diagnostic disable-next-line: assign-type-mismatch
                        errout,
                    },
                }, function(code, _)
                    if code == 0 then
                        echo_ok("build zls")
                        link_zls()
                    end
                end)

                ---@diagnostic disable-next-line: param-type-mismatch
                uv.read_start(errout, function(err, data)
                    assert(not err, err)
                    if data then
                        vim.schedule(function()
                            lib_notify.Warn(
                                string.format(
                                    "compile zls fails. err is %s",
                                    data
                                )
                            )
                        end)
                    end
                end)
            end
            do
                lib_git.clone(
                    "https://github.com/zigtools/zls.git",
                    config.options.zls.path,
                    function()
                        echo_ok("clone zls")
                        build_zls()
                    end
                )
            end
        end)
    end)
end

--- @param force boolean?
M.update = function(force)
    lib_util.dir_exists(config.options.zls.path, function(res)
        if not res then
            M.install()
            return
        end
        local build_zls = function()
            local errout = uv.new_pipe()
            ---@diagnostic disable-next-line: missing-fields
            lib_async.spawn("zig", {
                cwd = config.options.zls.path,
                args = {
                    "build",
                    build_arg(),
                },
                stdio = {
                    nil,
                    nil,
                    ---@diagnostic disable-next-line: assign-type-mismatch
                    errout,
                },
            }, function(code, _)
                if code == 0 then
                    echo_ok("update zls")
                else
                    vim.schedule(function()
                        lib_notify.Warn("build zls fails")
                    end)
                end
            end)
            echo_ok("start build")

            ---@diagnostic disable-next-line: param-type-mismatch
            uv.read_start(errout, function(err, data)
                assert(not err, err)
                if data then
                    vim.schedule(function()
                        lib_notify.Warn(
                            string.format("compile zls fails. err is %s", data)
                        )
                    end)
                end
            end)
        end

        lib_git.latest_commit(
            config.options.zls.path,
            false,
            function(local_commit)
                lib_git.latest_origin_commit(
                    config.options.zls.path,
                    function(remote_commit)
                        if local_commit ~= remote_commit then
                            lib_git.pull(config.options.zls.path, function()
                                echo_ok("pull zls")
                                build_zls()
                            end)
                        else
                            if force then
                                build_zls()
                            else
                                vim.schedule(function()
                                    lib_notify.Info("zls is the latest")
                                end)
                            end
                        end
                    end
                )
            end
        )
    end)
end

-- uninstall zls
-- this will delete all files about zls
M.uninstall = function()
    lib_util.delete_file(get_bin(), function(res)
        if not res then
            vim.schedule(function()
                lib_notify.Warn("delete zls bin dir fails")
            end)
            return
        end

        lib_util.delete_dir(config.options.zls.path, function(res_n)
            if not res_n then
                vim.schedule(function()
                    lib_notify.Warn("delete zls clone dir fails")
                end)
                return
            end
            echo_ok("zls uninstall")
        end)
    end)
end

--- @param callbak fun(data:string)
M.index_json = function(callbak)
    local out = uv.new_pipe()
    local errout = uv.new_pipe()
    ---@diagnostic disable-next-line: missing-fields
    lib_async.spawn("curl", {
        stdio = {
            nil,
            ---@diagnostic disable-next-line: assign-type-mismatch
            out,
            ---@diagnostic disable-next-line: assign-type-mismatch
            errout,
        },
        args = {
            "-s",
            "https://zigtools-releases.nyc3.digitaloceanspaces.com/zls/index.json",
        },
    }, function(_, _) end)
    ---@diagnostic disable-next-line: param-type-mismatch
    uv.read_start(out, function(err, data)
        assert(not err, err)
        if data then
            callbak(data)
        end
    end)
    ---@diagnostic disable-next-line: param-type-mismatch
    uv.read_start(errout, function(err, data)
        assert(not err, err)
        if data then
            vim.schedule(function()
                lib_notify.Warn(
                    string.format("curl download failed, err is %s", data)
                )
            end)
        end
    end)
end

M.config_lspconfig = function()
    local current_opt = {}
    local status_1, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
    if status_1 then
        current_opt.capabilities = cmp_nvim_lsp.default_capabilities()
    end
    current_opt = vim.tbl_deep_extend(
        "force",
        current_opt,
        config.options.zls.lspconfig_opt
    )
    local status_2, lspconfig = pcall(require, "lspconfig")
    if status_2 then
        lspconfig.zls.setup(current_opt)
    else
        lib_notify.Warn("not found lspconfig")
    end
end

return M
