local command = require("Zig.command")
local lib_util = require("Zig.lib.util")
local M = {}

local command_key = "version"

M.init = function()
    command.register_command(command_key, M.run, {})
end

M.run = function()
    lib_util.get_zig_version(function(version)
        vim.schedule(function()
            vim.api.nvim_echo({
                { "version: ", "DiagnosticHint" },
                { tostring(version.majro), "DiagnosticInfo" },
                { ".", "DiagnosticHint" },
                { tostring(version.minor), "DiagnosticInfo" },
                { ".", "DiagnosticHint" },
                { tostring(version.patch), "DiagnosticInfo" },
                { "-", "DiagnosticHint" },
                {
                    string.gsub(tostring(version.prerelease), "dev.", ""),
                    "DiagnosticWarn",
                },
                { "+", "DiagnosticHint" },
                { tostring(version.build), "DiagnosticWarn" },
            }, false, {})
        end)
    end)
end

-- whether this module is initialized

return M
