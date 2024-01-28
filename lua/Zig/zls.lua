local uv, api = vim.uv, vim.api
local command = require("Zig.command")
local config = require("Zig.config")
local lib_async = require("Zig.lib.async")
local lib_curl = require("Zig.lib.curl")
local lib_debug = require("Zig.lib.debug")
local lib_git = require("Zig.lib.git")
local lib_notify = require("Zig.lib.notify")
local lib_util = require("Zig.lib.util")

local M = {}

--- @class web_info
--- @field latest string
--- @field latest_tagged string
--- @field version string

--- @type web_info
local web_info = {
    latest = "",
    latest_tagged = "",
    version = "",
}

local default_data_path = vim.fn.stdpath("data") .. "/zig.nvim"

-- whether this module is initialized
local is_initialized = false

local command_key = "zls"

local build_arg = function()
    return string.format(
        "-Doptimize=%s",
        config.options.zls.source_install.build_mode
    )
end

--- @param str string
--- @param ok boolean
local function echo_ok(str, ok)
    vim.schedule(function()
        if ok then
            api.nvim_echo({
                { "Zig.nvim:", "" },
                { " ", "" },
                { str, "DiagnosticInfo" },
                { " ", "" },
                { "OK!", "DiagnosticOk" },
            }, false, {}) -- code
        else
            api.nvim_echo({
                { "Zig.nvim:", "" },
                { " ", "" },
                { str, "DiagnosticInfo" },
            }, false, {}) -- code
        end
    end)
end

--- @param version string?
--- @param callback fun()
local parse_zls_index_json = function(version, callback)
    echo_ok("start get index json", false)
    M.index_json(function(data)
        local status, tbl = pcall(vim.json.decode, data)
        if not status then
            vim.schedule(function()
                lib_notify.Warn("download json failed, please try again")
            end)
            return
        end
        web_info.latest_tagged = tbl["latestTagged"]
        web_info.latest = tbl["latest"]
        if (not version) or (version and tbl["versions"][version]) then
            callback()
        else
            vim.schedule(function()
                lib_notify.Error("The specified zls version does not exist")
            end)
        end
    end)
end

local get_bin_dir = function()
    return string.format("%s/bin", default_data_path)
end

-- get zls bin
local get_bin = function()
    return string.format(
        "%s/zls%s",
        get_bin_dir(),
        lib_util.is_win() and ".exe" or ""
    )
end

local add_zls_PATH = function()
    lib_util.file_exists(get_bin(), function(res)
        if res then
            vim.schedule(function()
                if not string.match(vim.env.PATH, get_bin_dir()) then
                    vim.env.PATH = string.format(
                        "%s%s%s",
                        vim.env.PATH,
                        lib_util.is_win() and ";" or ":",
                        get_bin_dir()
                    )
                end
            end)
        end
    end)
end

local remove_zls_PATH = function()
    if string.match(vim.env.PATH, get_bin_dir()) then
        vim.env.PATH = string.gsub(
            vim.env.PATH,
            string.format(
                "%s%s",
                lib_util.is_win() and ";" or ":",
                get_bin_dir()
            ),
            ""
        )
    end
end

--- @param callback fun(version:string?)
local get_zls_version = function(callback)
    lib_util.file_exists(get_bin(), function(res)
        if res then
            local errout = uv.new_pipe()
            local out = uv.new_pipe()

            --- @type string
            local out_data = ""
            ---@diagnostic disable-next-line: missing-fields
            lib_async.spawn(get_bin(), {
                args = {
                    "--version",
                },
                stdio = {
                    nil,
                    ---@diagnostic disable-next-line: assign-type-mismatch
                    out,
                    ---@diagnostic disable-next-line: assign-type-mismatch
                    errout,
                },
            }, function(code, _)
                ---@diagnostic disable-next-line: param-type-mismatch
                uv.close(out)
                ---@diagnostic disable-next-line: param-type-mismatch
                uv.close(errout)
                if code == 0 then
                    callback(string.gsub(out_data, "\n", ""))
                end
            end)

            ---@diagnostic disable-next-line: param-type-mismatch
            uv.read_start(out, function(err, data)
                assert(not err, err)

                if data then
                    out_data = out_data .. data
                end
            end)

            ---@diagnostic disable-next-line: param-type-mismatch
            uv.read_start(errout, function(err, data)
                assert(not err, err)
                if data then
                    vim.schedule(function()
                        lib_notify.Warn(
                            string.format(
                                "get zls version failed. err is %s",
                                data
                            )
                        )
                    end)
                end
            end)
        else
            callback(nil)
        end
    end)
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
        ["version"] = {},
    })

    add_zls_PATH()

    if config.options.zls.enable_lspconfig then
        lib_util.file_exists(get_bin(), function(res)
            if res then
                vim.schedule(function()
                    M.config_lspconfig()
                end)
            end
        end)
    end
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
    elseif param == "version" then
        get_zls_version(function(version)
            vim.schedule(function()
                if version then
                    lib_notify.Info(string.format("zls version: %s", version))
                else
                    lib_notify.Info("It seems you haven't installed zls yet")
                end
            end)
        end)
    else
        lib_notify.Info("not recognize param")
    end
end

--- @param callbak fun()
local copy_zls = function(callbak)
    lib_util.mkdir(get_bin_dir(), function()
        lib_util.copy_file(
            string.format(
                "%s/zig-out/bin/zls",
                config.options.zls.source_install.path
            ),
            get_bin(),
            function()
                echo_ok("copy zls", false)
                callbak()
            end
        )
    end)
end

local source_install = function()
    lib_util.delete_file(get_bin(), function(res)
        if not res then
            vim.schedule(function()
                lib_notify.Warn("delete the existing zls bin file fails")
            end)
            return
        end

        lib_util.delete_dir(
            config.options.zls.source_install.path,
            function(res_n)
                if not res_n then
                    vim.schedule(function()
                        lib_notify.Warn("delete existing zls git dir fails")
                    end)
                    return
                end

                local build_zls = function()
                    local errout = uv.new_pipe()
                    ---@diagnostic disable-next-line: missing-fields
                    lib_async.spawn("zig", {
                        cwd = config.options.zls.source_install.path,
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
                            echo_ok("build zls", false)
                            copy_zls(function()
                                echo_ok("install zls", true)
                                add_zls_PATH()
                            end)
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
                    echo_ok("clone zls", false)
                    lib_git.clone(
                        "https://github.com/zigtools/zls.git",
                        config.options.zls.source_install.path,
                        function()
                            echo_ok("start build zls", false)
                            build_zls()
                        end
                    )
                end
            end
        )
    end)
end

--- @param version string
local build_download_url = function(version)
    -- https://zigtools-releases.nyc3.digitaloceanspaces.com/zls/0.12.0-dev.111+ebbae55/x86_64-linux/zls

    local arch_name = "x86_64-linux/zls"

    if lib_util.is_win() then
        arch_name = "x86_64-windows/zls.exe"
    end

    return string.format(
        "https://zigtools-releases.nyc3.digitaloceanspaces.com/zls/%s/%s",
        version,
        arch_name
    )
end

local web_install = function()
    local web_version = config.options.zls.web_install.version

    lib_util.delete_file(get_bin(), function(res)
        if not res then
            vim.schedule(function()
                lib_notify.Warn("delete the existing zls bin file fails")
            end)
            return
        end
        if web_version == "latest" or web_version == "latestTagged" then
            parse_zls_index_json(nil, function()
                if web_version == "latest" then
                    echo_ok("start download latest", false)
                    lib_curl.download_file(
                        build_download_url(web_info.latest),
                        get_bin(),
                        function()
                            echo_ok("chmod exec zls", false)
                            lib_util.chmod_exec(get_bin(), function(res_n)
                                if res_n then
                                    echo_ok("install zls", true)
                                    add_zls_PATH()
                                else
                                    vim.schedule(function()
                                        lib_notify.Warn(
                                            "chmod exec to zls failed"
                                        )
                                    end)
                                end
                            end)
                        end
                    )
                else
                    echo_ok("start download latest_tagged", false)
                    lib_curl.download_file(
                        build_download_url(web_info.latest_tagged),
                        get_bin(),
                        function()
                            echo_ok("chmod exec zls", false)
                            lib_util.chmod_exec(get_bin(), function(res_n)
                                if res_n then
                                    echo_ok("install zls", true)
                                    add_zls_PATH()
                                else
                                    vim.schedule(function()
                                        lib_notify.Warn(
                                            "chmod exec to zls failed"
                                        )
                                    end)
                                end
                            end)
                        end
                    )
                end
            end)
        else
            parse_zls_index_json(web_version, function()
                echo_ok("start download customed version", false)
                lib_curl.download_file(
                    ---@diagnostic disable-next-line: param-type-mismatch
                    build_download_url(web_version),
                    get_bin(),
                    function()
                        echo_ok("chmod exec zls", false)
                        lib_util.chmod_exec(get_bin(), function(res_n)
                            if res_n then
                                echo_ok("install zls", true)
                                add_zls_PATH()
                            else
                                vim.schedule(function()
                                    lib_notify.Warn("chmod exec to zls failed")
                                end)
                            end
                        end)
                    end
                )
            end)
        end
    end)
end

M.install = function()
    if config.options.zls.get_method == "source_build" then
        source_install()
    elseif config.options.zls.get_method == "web" then
        web_install()
    end
end

local source_update = function(force)
    lib_util.dir_exists(config.options.zls.source_install.path, function(res)
        if not res then
            M.install()
            return
        end
        local build_zls = function()
            local errout = uv.new_pipe()
            ---@diagnostic disable-next-line: missing-fields
            lib_async.spawn("zig", {
                cwd = config.options.zls.source_install.path,
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
                    copy_zls(function()
                        echo_ok("update zls", true)
                    end)
                else
                    vim.schedule(function()
                        lib_notify.Warn("build zls fails")
                    end)
                end
            end)
            echo_ok("start build", false)

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
            config.options.zls.source_install.path,
            false,
            function(local_commit)
                lib_git.latest_origin_commit(
                    config.options.zls.source_install.path,
                    function(remote_commit)
                        if local_commit ~= remote_commit then
                            echo_ok("pull zls", true)
                            lib_git.pull(
                                config.options.zls.source_install.path,
                                function()
                                    echo_ok("build zls", false)
                                    build_zls()
                                end
                            )
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

local web_update = function()
    get_zls_version(function(version)
        if not version then
            echo_ok("start install zls", false)
            web_install()
            return
        end

        local web_version = config.options.zls.web_install.version
        if web_version == "latest" or web_version == "latestTagged" then
            parse_zls_index_json(nil, function()
                local latest_version
                local url
                if web_version == "latest" then
                    latest_version = web_info.latest
                    url = build_download_url(web_info.latest)
                else
                    latest_version = web_info.latest_tagged
                    url = build_download_url(web_info.latest)
                end
                if latest_version ~= version then
                    echo_ok(
                        string.format("start download new %s zls", web_version),
                        false
                    )
                    lib_curl.download_file(url, get_bin(), function()
                        echo_ok("chmod exec zls", false)
                        lib_util.chmod_exec(get_bin(), function(res)
                            if res then
                                echo_ok("update zls", true)
                            else
                                vim.schedule(function()
                                    lib_notify.Warn("chmod exec to zls failed")
                                end)
                            end
                        end)
                    end)
                else
                    vim.schedule(function()
                        lib_notify.Info("zls is the latest")
                    end)
                end
            end)
        else
            vim.schedule(function()
                lib_notify.Info("you are using a customed version!")
            end)
        end
    end)
end

--- @param force boolean?
M.update = function(force)
    if config.options.zls.get_method == "source_build" then
        source_update(force)
    elseif config.options.zls.get_method == "web" then
        web_update()
    end
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

        lib_util.delete_dir(
            config.options.zls.source_install.path,
            function(res_n)
                if not res_n then
                    vim.schedule(function()
                        lib_notify.Warn("delete zls clone dir fails")
                    end)
                    return
                end
                vim.schedule(function()
                    remove_zls_PATH()
                end)
                echo_ok("zls uninstall", true)
            end
        )
    end)
end

--- @param callbak fun(data:string)
M.index_json = function(callbak)
    local out = uv.new_pipe()
    local errout = uv.new_pipe()
    --- @type string
    local out_data = ""
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
    }, function(code, _)
        ---@diagnostic disable-next-line: param-type-mismatch
        uv.close(out)
        ---@diagnostic disable-next-line: param-type-mismatch
        uv.close(errout)
        if code == 0 then
            callbak(out_data)
        end
    end)
    ---@diagnostic disable-next-line: param-type-mismatch
    uv.read_start(out, function(err, data)
        assert(not err, err)
        if data then
            out_data = out_data .. data
        end
    end)
    ---@diagnostic disable-next-line: param-type-mismatch
    uv.read_start(errout, function(err, data)
        assert(not err, err)
        if data then
            vim.schedule(function()
                lib_notify.Warn(
                    string.format(
                        "curl download zls index json failed, err is %s",
                        data
                    )
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
