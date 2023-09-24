local uv, api = vim.uv, vim.api
local command = require("Zig.command")
local config = require("Zig.config")
local lib_async = require("Zig.lib.async")
local lib_notify = require("Zig.lib.notify")
local lib_util = require("Zig.lib.util")

local M = {}

local command_key = "fmt"

-- whether this module is initialized
local is_initialized = false

--- @type string[]
local g_original_lines

---@param a? string
---@param b? string
---@return integer
local function common_prefix_len(a, b)
    if not a or not b then
        return 0
    end
    local min_len = math.min(#a, #b)
    for i = 1, min_len do
        if string.byte(a, i) ~= string.byte(b, i) then
            return i - 1
        end
    end
    return min_len
end

---@param a string
---@param b string
---@return integer
local function common_suffix_len(a, b)
    local a_len = #a
    local b_len = #b
    local min_len = math.min(a_len, b_len)
    for i = 0, min_len - 1 do
        if string.byte(a, a_len - i) ~= string.byte(b, b_len - i) then
            return i
        end
    end
    return min_len
end

local function create_text_edit(
    original_lines,
    replacement,
    is_insert,
    is_replace,
    orig_line_start,
    orig_line_end
)
    local start_line, end_line = orig_line_start - 1, orig_line_end - 1
    local start_char, end_char = 0, 0
    if is_replace then
        -- If we're replacing text, see if we can avoid replacing the entire line
        start_char =
            common_prefix_len(original_lines[orig_line_start], replacement[1])
        if start_char > 0 then
            replacement[1] = replacement[1]:sub(start_char + 1)
        end

        if original_lines[orig_line_end] then
            local last_line = replacement[#replacement]
            local suffix =
                common_suffix_len(original_lines[orig_line_end], last_line)
            -- If we're only replacing one line, make sure the prefix/suffix calculations don't overlap
            if orig_line_end == orig_line_start then
                suffix = math.min(
                    suffix,
                    original_lines[orig_line_end]:len() - start_char
                )
            end
            end_char = original_lines[orig_line_end]:len() - suffix
            if suffix > 0 then
                replacement[#replacement] =
                    last_line:sub(1, last_line:len() - suffix)
            end
        end
    end
    -- If we're inserting text, make sure the text includes a newline at the end.
    -- The one exception is if we're inserting at the end of the file, in which case the newline is
    -- implicit
    if is_insert and start_line < #original_lines then
        table.insert(replacement, "")
    end
    local new_text = table.concat(replacement, "\n")

    return {
        newText = new_text,
        range = {
            start = {
                line = start_line,
                character = start_char,
            },
            ["end"] = {
                line = end_line,
                character = end_char,
            },
        },
    }
end

M.apply_fmt = function(bufnr, original_lines, new_lines)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    -- The vim.diff algorithm doesn't handle changes in newline-at-end-of-file well. The unified
    -- result_type has some text to indicate that the eol changed, but the indices result_type has no
    -- such indication. To work around this, we just add a trailing newline to the end of both the old
    -- and the new text.
    table.insert(original_lines, "")
    table.insert(new_lines, "")
    local original_text = table.concat(original_lines, "\n")
    local new_text = table.concat(new_lines, "\n")
    table.remove(original_lines)
    table.remove(new_lines)

    --- @type table
    --- @diagnostic disable-next-line: assign-type-mismatch
    local indices = vim.diff(original_text, new_text, {
        result_type = "indices",
        algorithm = "histogram",
    })
    assert(indices)
    local text_edits = {}
    for _, idx in ipairs(indices) do
        local orig_line_start, orig_line_count, new_line_start, new_line_count =
            unpack(idx)
        local is_insert = orig_line_count == 0
        local is_delete = new_line_count == 0
        local is_replace = not is_insert and not is_delete
        local orig_line_end = orig_line_start + orig_line_count
        local new_line_end = new_line_start + new_line_count

        if is_insert then
            -- When the diff is an insert, it actually means to insert after the mentioned line
            orig_line_start = orig_line_start + 1
            orig_line_end = orig_line_end + 1
        end

        local replacement =
            lib_util.tbl_slice(new_lines, new_line_start, new_line_end)

        -- For replacement edits, convert the end line to be inclusive
        if is_replace then
            orig_line_end = orig_line_end - 1
        end
        local text_edit = create_text_edit(
            original_lines,
            replacement,
            is_insert,
            is_replace,
            orig_line_start,
            orig_line_end
        )
        table.insert(text_edits, text_edit)
    end

    vim.lsp.util.apply_text_edits(text_edits, bufnr, "utf-8")
end

local function fmt_file(path)
    local fd = uv.fs_open(path, "r", 438)
    if not fd then
        lib_notify.Info("file is not exist!")
        return
    end
    local status = uv.fs_fstat(fd)
    if not status then
        lib_notify.Info("get file status fails!")
        return
    end
    if status.type ~= "file" then
        lib_notify.Info("please input a file path!")
        return
    end

    local file_name = assert(vim.fs.basename(path))
    local arr = vim.fn.split(file_name, "\\.")
    local type = arr[#arr]
    if type ~= "zon" and type ~= "zig" then
        lib_notify.Info('your file in not "*.zig" or ".zon"')
        return
    end

    local stdin = assert(uv.new_pipe())
    local stdout = assert(uv.new_pipe())
    local stderr = assert(uv.new_pipe())

    lib_async.spawn(
        "zig",
        ---@diagnostic disable-next-line: missing-fields
        {
            stdio = {
                ---@diagnostic disable-next-line: assign-type-mismatch
                stdin,
                ---@diagnostic disable-next-line: assign-type-mismatch
                stdout,
                ---@diagnostic disable-next-line: assign-type-mismatch
                stderr,
            },
            args = {
                "fmt",
                path,
            },
        },
        ---@diagnostic disable-next-line: unused-local
        function(code, signal)
            --- @type string
            local message
            if code == 0 then
                message = "fmt file success!"
            else
                message = "fmt file fails!"
            end
            vim.schedule(function()
                lib_notify.Info(message)
            end)
        end,
        ---@diagnostic disable-next-line: unused-local
        function(err, data)
            assert(not err, err)
        end,
        ---@diagnostic disable-next-line: unused-local
        function(err, data)
            assert(not err, err)
        end
    )

    uv.shutdown(stdin)
    uv.shutdown(stdout)
    uv.shutdown(stderr)
end

local function fmt_buffer()
    local current_buffer = api.nvim_get_current_buf()

    local filetype = api.nvim_get_option_value("filetype", {
        buf = current_buffer,
    })

    if filetype ~= "zig" then
        return
    end

    g_original_lines = vim.api.nvim_buf_get_lines(current_buffer, 0, -1, false)

    local buffer_text = table.concat(g_original_lines, "\n")

    local stdin = assert(uv.new_pipe())
    local stdout = assert(uv.new_pipe())
    local stderr = assert(uv.new_pipe())

    lib_async.spawn(
        "zig",
        ---@diagnostic disable-next-line: missing-fields
        {
            stdio = {
                ---@diagnostic disable-next-line: assign-type-mismatch
                stdin,
                ---@diagnostic disable-next-line: assign-type-mismatch
                stdout,
                ---@diagnostic disable-next-line: assign-type-mismatch
                stderr,
            },
            args = {
                "fmt",
                "--stdin",
            },
        },
        ---@diagnostic disable-next-line: unused-local
        function(code, signal) end,
        function(err, data)
            assert(not err, err)
            uv.shutdown(stdout)
            if data then
                vim.schedule(function()
                    local output = vim.split(data, "\n", { plain = true })
                    table.remove(output)
                    M.apply_fmt(current_buffer, g_original_lines, output)
                end)
            end
        end,
        function(err, data)
            assert(not err, err)
            uv.shutdown(stderr)
            if data then
                vim.schedule(function()
                    lib_notify.Info("fmt fails, please check syntax!")
                    -- TODO:need fmt the err message
                end)
            end
        end
    )

    -- write the buffer_text to stdin
    uv.write(stdin, buffer_text)
    -- close the stdin
    uv.shutdown(stdin)
end

-- init for fmt
M.init = function()
    if not config.options.fmt then
        return
    end

    if is_initialized then
        return
    end

    is_initialized = true

    command.register_command(command_key, M.run, {})
end

-- deinit for fmt
M.deinit = function()
    if not is_initialized then
        return
    end

    is_initialized = false

    command.unregister_command(command_key)
end

-- run for fmt
--- @param arg string[]
M.run = function(arg)
    if #arg > 0 then
        fmt_file(arg[1])
    else
        fmt_buffer()
    end
end

return M
