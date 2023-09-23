local uv, api = vim.uv, vim.api
local command = require("Zig.command")
local lib_async = require("Zig.lib.async")
local lib_debug = require("Zig.lib.debug")
local lib_util = require("Zig.lib.util")

local M = {}

local original_lines

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

M.apply_format = function(bufnr, original_lines, new_lines)
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

    local indices = vim.diff(original_text, new_text, {
        result_type = "indices",
        algorithm = "histogram",
    })
    assert(indices)
    local text_edits = {}
    for _, idx in ipairs(indices) do
        local orig_line_start, orig_line_count, new_line_start, new_line_count =
            unpack(idx)
        lib_debug.debug(idx)
        lib_debug.debug(
            orig_line_start,
            orig_line_count,
            new_line_start,
            new_line_count
        )
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

local function format_file() end

local function format_buffer()
    local current_buffer = api.nvim_get_current_buf()
    local filetype = api.nvim_get_option_value("filetype", {
        buf = current_buffer,
    })
    if filetype ~= "zig" then
        return
    end
    original_lines = vim.api.nvim_buf_get_lines(current_buffer, 0, -1, false)

    local buffer_text = table.concat(original_lines, "\n")

    local stdin, process = lib_async.spawn(
        "zig",
        ---@diagnostic disable-next-line: missing-fields
        {
            args = {
                "fmt",
                "--stdin",
            },
        },
        function(code, signal)
            -- print(string.format("exit, code: %d, signal: %d", code, signal))
        end,
        function(err, data)
            assert(not err, err)
            if data then
                vim.schedule(function()
                    local output = vim.split(data, "\n", { plain = true })
                    table.remove(output)
                    M.apply_format(current_buffer, original_lines, output)
                end)
            end
        end,
        function(err, data)
            assert(not err, err)
            -- if data then
            --     print("stderr: ", data)
            -- else
            --     print("stderr end")
            -- end
        end
    )

    -- write the buffer_text to stdin
    uv.write(stdin, buffer_text)
    -- close the stdin
    uv.shutdown(stdin, function() end)
end

M.init = function()
    command.register_command("format", M.run, {})
end

M.run = function()
    format_buffer()
end

return M
