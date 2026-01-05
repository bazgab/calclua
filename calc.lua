-- calclua
-- A simple TUI calculator in Lua 5.1
-- Features: Inline Display, Direct Input
--------------------------------------------------------------------------------
-- 1. CONFIGURATION & ANSI CODES
--------------------------------------------------------------------------------

local KEYPAD = {
    { "C", "/", "*", "-" },
    { "7", "8", "9", "+" },
    { "4", "5", "6", "^" },
    { "1", "2", "3", "=" },
    { "0", ".", "OFF", "" }
}

-- Layout Constants (Increased for spacing)
local UI_WIDTH  = 65  -- Wider to fit new spacing
local UI_HEIGHT = 20  -- Taller to fit vertical gaps

-- ANSI Escape Sequences
local ESC = "\27"
local HIDE_CURSOR = ESC .. "[?25l"
local SHOW_CURSOR = ESC .. "[?25h"
local RESET_COLOR = ESC .. "[0m"
local TEXT_GREEN  = ESC .. "[32m"
local TEXT_GRAY   = ESC .. "[90m" 
local TEXT_WHITE  = ESC .. "[37m"
local FRAME_COLOR = ESC .. "[36m" -- Cyan

-- Helper to move cursor UP N lines
local function cursor_up(n)
    return ESC .. "[" .. n .. "A"
end

--------------------------------------------------------------------------------
-- 2. STATE MANAGEMENT
--------------------------------------------------------------------------------

local state = {
    display = "0",
    accumulator = 0,
    operator = nil,
    new_entry = true,
    history = {}
}

local buffer = {}

--------------------------------------------------------------------------------
-- 3. BUFFER & RENDER LOGIC
--------------------------------------------------------------------------------

local function clear_buffer()
    for y = 1, UI_HEIGHT do
        buffer[y] = {}
        for x = 1, UI_WIDTH do
            buffer[y][x] = " "
        end
    end
end

local function buf_write(x, y, text, color)
    local s_text = tostring(text)
    for i = 1, #s_text do
        local char = string.sub(s_text, i, i)
        if buffer[y] and buffer[y][x + i - 1] then
            local cell = char
            if color then cell = color .. char .. RESET_COLOR end
            buffer[y][x + i - 1] = cell
        end
    end
end

local function render_view()
    io.write(cursor_up(UI_HEIGHT))
    for y = 1, UI_HEIGHT do
        local line_str = table.concat(buffer[y])
        io.write("\r" .. line_str .. "\n")
    end
end

--------------------------------------------------------------------------------
-- 4. LOGIC ENGINE
--------------------------------------------------------------------------------

local function add_to_history(val1, op, val2, result)
    local entry = string.format("%g %s %g = %g", val1, op, val2, result)
    table.insert(state.history, 1, entry)
    if #state.history > 12 then table.remove(state.history) end
end

local function calculate()
    local curr = tonumber(state.display) or 0
    local acc = state.accumulator
    local op = state.operator
    local res = curr

    if op == "+" then res = acc + curr
    elseif op == "-" then res = acc - curr
    elseif op == "*" then res = acc * curr
    elseif op == "/" then 
        if curr == 0 then res = "Err" else res = acc / curr end
    elseif op == "^" then res = acc ^ curr
    end

    if op and type(res) == "number" then
        add_to_history(acc, op, curr, res)
    end

    if type(res) == "number" and res == math.floor(res) then
        state.display = string.format("%.0f", res)
    else
        state.display = tostring(res)
    end
    
    state.accumulator = tonumber(state.display) or 0
    state.new_entry = true
    state.operator = nil
end

local function handle_input(key)
    key = string.upper(key)

    if tonumber(key) or key == "." then
        if state.new_entry then
            state.display = key
            state.new_entry = false
        else
            if key == "." and string.find(state.display, "%.") then return end
            state.display = state.display .. key
        end
        return
    end

    if key == "C" or key == "BACKSPACE" then
        state.display = "0"
        state.accumulator = 0
        state.operator = nil
        state.new_entry = true
    elseif key == "=" then
        if state.operator then calculate() end
    elseif key == "OFF" then
        return "quit"
    elseif key == "" then
        return
    end

    local valid_ops = { ["+"]=true, ["-"]=true, ["*"]=true, ["/"]=true, ["^"]=true }
    if valid_ops[key] then
        if state.operator and not state.new_entry then calculate() end
        state.accumulator = tonumber(state.display) or 0
        state.operator = key
        state.new_entry = true
    end
end

--------------------------------------------------------------------------------
-- 5. DRAWING TO BUFFER
--------------------------------------------------------------------------------

local function draw_ui()
    clear_buffer()

    -- Adjusted coordinates for a larger body
    local shell_x = 2
    local shell_y = 1
    local shell_width = 38        -- Widened (was 34)
    local shell_height = 18       -- Tallened (was 14)
    local inner_x = shell_x + 2
    local inner_y = shell_y + 1

    -- === 1. DRAW CHASSIS ===
    buf_write(shell_x, shell_y, "." .. string.rep("-", shell_width - 2) .. ".", FRAME_COLOR)
    for i = 1, shell_height - 2 do
        buf_write(shell_x, shell_y + i, "|", FRAME_COLOR)
        buf_write(shell_x + shell_width - 1, shell_y + i, "|", FRAME_COLOR)
    end
    buf_write(shell_x, shell_y + shell_height - 1, "'" .. string.rep("-", shell_width - 2) .. "'", FRAME_COLOR)

    -- === 2. SCREEN ===
    -- Widen the screen box to match new shell width
    local screen_line = "+-------------------------------+"
    buf_write(inner_x, inner_y, screen_line)
    
    local op_char = state.operator or " "
    -- Adjusted format for wider screen
    local display_content = string.format("| %1s %27s |", op_char, state.display)
    buf_write(inner_x, inner_y + 1, display_content)
    buf_write(inner_x, inner_y + 2, screen_line)

    -- === 3. KEYPAD ===
    local keypad_start_y = inner_y + 4
    
    for r, row in ipairs(KEYPAD) do
        local line_str = " " -- Initial padding
        for c, label in ipairs(row) do
            -- INCREASED SPACING: "  %-3s   " adds more air around numbers
            line_str = line_str .. string.format("  %-3s   ", label)
        end
        
        -- VERTICAL SPACING: We multiply row index 'r' by 2 to skip lines
        -- (r-1)*2 ensures row 1 is at 0 offset, row 2 is at 2 offset, etc.
        local draw_y = keypad_start_y + (r - 1) * 2
        
        buf_write(inner_x, draw_y, line_str)
    end
    
    -- === 4. INSTRUCTIONS & TAPE ===
    -- Instructions below chassis
    buf_write(shell_x, shell_y + shell_height, "Type numbers directly.", TEXT_GRAY)
    buf_write(shell_x, shell_y + shell_height + 1, "ENTER = Equal. Q to Quit.", TEXT_GRAY)

    -- History Tape (Right side)
    local tape_x = shell_x + shell_width + 4
    buf_write(tape_x, shell_y, "HISTORY TAPE")
    buf_write(tape_x, shell_y + 1, "------------")

    for i, entry in ipairs(state.history) do
        if shell_y + 1 + i <= UI_HEIGHT then
            local color = (i == 1) and TEXT_WHITE or TEXT_GRAY
            buf_write(tape_x, shell_y + 1 + i, entry, color)
        end
    end
end

--------------------------------------------------------------------------------
-- 6. MAIN LOOP
--------------------------------------------------------------------------------

local function read_key()
    local char = io.read(1)
    if char == "\27" then
        io.read(1); io.read(1)
        return nil 
    end
    return char
end

local function main()
    -- 1. Reserve vertical space
    for i=1, UI_HEIGHT do io.write("\n") end

    -- 2. Setup
    os.execute("stty -echo -icanon min 1 time 0")
    io.write(HIDE_CURSOR)

    local status, err = pcall(function()
        while true do
            draw_ui()
            render_view()

            local key = read_key()
            if key then 
                if string.byte(key) == 13 or string.byte(key) == 10 then
                    handle_input("=")
                elseif key == "q" or key == "Q" then
                    break
                elseif key == "\127" or key == "\8" then 
                    handle_input("C")
                else
                    handle_input(key) 
                end
            end
        end
    end)

    -- 3. Cleanup
    os.execute("stty echo icanon")
    io.write(SHOW_CURSOR .. RESET_COLOR)
    
    if not status then
        print("Error: " .. tostring(err))
    end
end

main()
