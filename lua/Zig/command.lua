local api, fn = vim.api, vim.fn

local lib_debug = require("Zig.lib.debug")
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
--- @param args string[]?
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
        if #args.fargs > 0 then
            local key = args.fargs[1]
            table.remove(args.fargs, 1)
            exec(key, args.fargs)
        else
            exec()
        end
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

            -- when args is function
            if type(args) == "function" then
                local args_new = {}
                for i = 3, #cmd, 1 do
                    if cmd[2] then
                        table.insert(args_new, cmd[i])
                    end
                end
                return args_new(args_new)
            end

            local tmp = args
            for i = 3, #cmd, 1 do
                local current_key = cmd[i]
                if tmp[current_key] then
                    tmp = tmp[current_key]
                else
                    return vim.tbl_keys(tmp)
                end
            end

            return vim.tbl_keys(tmp)
        end,
    })
end

-- this function register command
--- @param command_key string
--- @param run function
--- @param args table
M.register_command = function(command_key, run, args)
    command_store[command_key] = command_store[command_key] or {}
    command_store[command_key].run = run
    command_store[command_key].args = args
end

-- this function unregister command
--- @param command_key string
M.unregister_command = function(command_key)
    if command_store[command_key] then
        command_store[command_key] = nil
    end
end

return M
