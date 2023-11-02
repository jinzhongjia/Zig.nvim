local health = vim.health
local M = {}

local check_zig = function()
    health.start("check zig")
    if vim.fn.executable("zig") == 1 then
        health.ok("found zig")
    else
        health.error("not found zig")
    end
end

local check_curl = function()
    health.start("check curl")
    if vim.fn.executable("curl") == 1 then
        health.ok("found curl")
    else
        health.error("not found curl")
    end
end

M.check = function()
    check_zig()
    check_curl()
end
return M
