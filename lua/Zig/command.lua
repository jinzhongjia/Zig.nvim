local api, fn = vim.api, vim.fn

local lib_notify = require("Zig.lib.notify")
local util = require("Zig.lib.util")

local command_store = {}

-- get command keys
--- @return string[]
local function command_keys()
    return vim.tbl_keys(command_store)
end

-- the default function when command `Zig` execute
local function default_exec()
    lib_notify.Info(string.format("Version is %s", util.version()))
end

-- exec run function
--- @param key string?
--- @param args any
local function exec(key, args)
    if key == nil then
        default_exec()
    else
        if command_store[key] then
            pcall(command_store[key].run, args)
        else
            lib_notify.Warn(string.format("command %s not exist!", key))
        end
    end
end

local M = {}

-- init for the command
M.init = function()
    api.nvim_create_user_command("Zig", function(args)
        exec(unpack(args.fargs))
    end, {
        range = true,
        nargs = "*",
        complete = function(_, cmdline, _)
            local cmd = fn.split(cmdline)
            local key_list = command_keys()

            if #cmd <= 1 then
                return key_list
            end

            local args = vim.tbl_get(command_store, cmd[2], "args")
            if not args then
                return {}
            end

            return args
        end,
    })
end

-- this function register command
--- @param command_key string
--- @param run function
--- @param args string[]
M.register_command = function(command_key, run, args)
    command_store[command_key] = command_store[command_key] or {}
    command_store[command_key].run = run
    command_store[command_key].args = args
end

return M