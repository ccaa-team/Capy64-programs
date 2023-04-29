local fs = require("fs")
local io = require("io")
local timer = require("timer")

local registerSize = 16

-- Contains all the program instructions parsed from the source file
local program = {}
local currentLine = 0

local register = {}
local stack = {}
local exit = false
local function panic(msg)
    exit = true
    local command = program[currentLine]
    print(string.format("Line %d: %s\n%s", command.sourcePosition, command.sourceLine, msg))
end

local function resolveNumber(val)
    local output
    val = val:gsub("_", "")
    if val:sub(1, 2) == "0x" then
        output = tonumber(val:sub(3), 16)
    else
        output = tonumber(val)
    end
    if not output then
        return panic("Invalid value")
    end
    return output
end

local specialRegistersGetters = {
    nul = function() return 0 end,
    top = function() return #stack end,
    cur = function() return currentLine end,
}

local function getRegisterValue(index)
    if specialRegistersGetters[index] then
        return specialRegistersGetters[index]()
    end
    index = resolveNumber(index)
    if index < 0 or index >= registerSize then
        return panic("Invalid register")
    end
    return register[index]
end

local function resolveStackIndex(index)
    if index >= 0 then
        return index
    end

    return #stack + index + 1
end

local function getStackValue(index)
    index = resolveStackIndex(index)
    if index == 0 then
        return 0
    else
        if not stack[index] then
            return 0
        end
        return stack[index]
    end
end

local function getValue(key)
    -- Prefix $ means register
    -- Prefix % means stack
    -- No prefix means raw value
    -- Supports hex values

    if key:sub(1, 1) == "$" then
        local index = key:sub(2)
        return getRegisterValue(index)
    elseif key:sub(1, 1) == "%" then
        local index = key:sub(2)
        index = resolveNumber(index)
        return getStackValue(index)
    end

    return resolveNumber(key)
end

local function setRegisterValue(index, value)
    if specialRegistersGetters[index] then
        return
    end
    if type(index) == "string" then
        if index:sub(1, 1) == "$" then
            index = index:sub(2)
        end
        index = resolveNumber(index)
    end

    if not index or index < 0 or index >= registerSize then
        return panic("Invalid register")
    end
    register[index] = value
end

local function pushStackValue(value)
    table.insert(stack, value)
end

local function popStackValues(count)
    for i = 1, count do
        table.remove(stack)
    end
end

local function popStackValue()
    return table.remove(stack)
end

local function peekStackValue()
    return stack[#stack]
end

local function jumpToLabel(label)
    for i = 1, #program do
        local command = program[i]
        if command.type == "label" and command.name == label then
            currentLine = i
            return
        end
    end
end

-- Instructions

local instructions = {}

-- Basic instructions
function instructions.hlt()
    exit = true
end

-- Do nothing successfully
function instructions.nop()
end

function instructions.slp(value)
    local time = getValue(value)
    timer.sleep(time)
end

function instructions.out(value)
    print(getValue(value))
end

function instructions.mov(index, value)
    setRegisterValue(index, getValue(value))
end

function instructions.psh(value)
    pushStackValue(getValue(value))
end

function instructions.pop(count)
    count = resolveNumber(count)
    popStackValues(count)
end

function instructions.top(newIndex)
    local index = getValue(newIndex)
    local toRemove = #stack - index
    if toRemove > 0 then
        popStackValues(toRemove)
    end
end

function instructions.swp()
    local a = popStackValue()
    local b = popStackValue()
    pushStackValue(a)
    pushStackValue(b)
end

-- Arithmetic instructions

function instructions.add()
    local b = popStackValue()
    local a = popStackValue()

    if not b or not a then
        return panic("Stack underflow")
    end
    pushStackValue(a + b)
end

function instructions.sub()
    local b = popStackValue()
    local a = popStackValue()

    if not b or not a then
        return panic("Stack underflow")
    end
    pushStackValue(a - b)
end

function instructions.mul()
    local b = popStackValue()
    local a = popStackValue()

    if not b or not a then
        return panic("Stack underflow")
    end
    pushStackValue(a * b)
end

function instructions.div()
    local b = popStackValue()
    local a = popStackValue()

    if not b or not a then
        return panic("Stack underflow")
    end
    pushStackValue(a / b)
end

function instructions.idiv()
    local b = popStackValue()
    local a = popStackValue()

    if not b or not a then
        return panic("Stack underflow")
    end
    pushStackValue(a // b)
end

function instructions.mod()
    local b = popStackValue()
    local a = popStackValue()

    if not b or not a then
        return panic("Stack underflow")
    end
    pushStackValue(a % b)
end

function instructions.pow()
    local b = popStackValue()
    local a = popStackValue()

    if not b or not a then
        return panic("Stack underflow")
    end
    pushStackValue(a ^ b)
end

function instructions.unm()
    local a = popStackValue()
    pushStackValue(-a)
end

-- Bitwise instructions

instructions["not"] = function()
    local a = popStackValue()
    pushStackValue(~a)
end

instructions["and"] = function()
    local b = popStackValue()
    local a = popStackValue()
    pushStackValue(a & b)
end

instructions["or"] = function()
    local b = popStackValue()
    local a = popStackValue()
    pushStackValue(a | b)
end

instructions["xor"] = function()
    local b = popStackValue()
    local a = popStackValue()
    pushStackValue(a ~ b)
end

instructions["lsh"] = function()
    local b = popStackValue()
    local a = popStackValue()
    pushStackValue(a << b)
end

instructions["rsh"] = function()
    local b = popStackValue()
    local a = popStackValue()
    pushStackValue(a >> b)
end

-- Comparison instructions

function instructions.cmp()
    local b = popStackValue()
    local a = popStackValue()
    pushStackValue(a == b and 1 or 0)
end

function instructions.cgt()
    local b = popStackValue()
    local a = popStackValue()
    pushStackValue(a > b and 1 or 0)
end

function instructions.clt()
    local b = popStackValue()
    local a = popStackValue()
    pushStackValue(a < b and 1 or 0)
end

function instructions.cge()
    local b = popStackValue()
    local a = popStackValue()
    pushStackValue(a >= b and 1 or 0)
end

function instructions.cle()
    local b = popStackValue()
    local a = popStackValue()
    pushStackValue(a <= b and 1 or 0)
end

function instructions.cne()
    local b = popStackValue()
    local a = popStackValue()
    pushStackValue(a ~= b and 1 or 0)
end

-- Control flow instructions

function instructions.jmp(label)
    jumpToLabel(label)
end

-- Branch instructions

function instructions.je(label)
    local value = popStackValue()
    if value > 0 then
        jumpToLabel(label)
    end
end

function instructions.jnz(label)
    local value = popStackValue()
    if value ~= 0 then
        jumpToLabel(label)
    end
end

-- If instructions

function instructions.ife(a, b, label)
    if getValue(a) == getValue(b) then
        jumpToLabel(label)
    end
end

function instructions.ifgt(a, b, label)
    if getValue(a) > getValue(b) then
        jumpToLabel(label)
    end
end

function instructions.iflt(a, b, label)
    if getValue(a) < getValue(b) then
        jumpToLabel(label)
    end
end

function instructions.ifge(a, b, label)
    if getValue(a) >= getValue(b) then
        jumpToLabel(label)
    end
end

function instructions.ifle(a, b, label)
    if getValue(a) <= getValue(b) then
        jumpToLabel(label)
    end
end

function instructions.ifne(a, b, label)
    if getValue(a) ~= getValue(b) then
        jumpToLabel(label)
    end
end

-- Debug instructions

function instructions.dbg()
    print("Registers:")
    for i = 1, #register do
        print(i, register[i])
    end
    print("Stack:")
    for i = 1, #stack do
        print(i, stack[i])
    end
end

-- Parsing and execution
local function parseLine(line, lineNumber)
    local command = {
        sourcePosition = lineNumber,
        sourceLine = line,
    }

    local parts = {}
    for part in line:gmatch("%S+") do
        table.insert(parts, part)
    end

    local instruction = table.remove(parts, 1)

    if instruction:sub(#instruction) == ":" then
        command.type = "label"
        command.name = instruction:sub(1, #instruction - 1)
        return command
    end

    command.type = "instruction"
    command.instruction = instruction
    command.args = {}
    local combinedArgs = table.concat(parts, "")
    for arg in combinedArgs:gmatch("[^,]+") do
        table.insert(command.args, arg)
    end

    return command
end

local function parseSource(lines)
    for i = 1, #lines do
        -- Remove comments and trim whitespace
        local line = lines[i]:gsub(";.*", ""):gsub("^%s*(.-)%s*$", "%1")
        if line ~= "" then
            local command = parseLine(line, i)
            table.insert(program, command)
        end
    end
end

local function execute()
    while not exit and currentLine < #program do
        currentLine = currentLine + 1
        local command = program[currentLine]
        if command.type == "instruction" then
            local instruction = instructions[command.instruction]
            if instruction then
                instruction(table.unpack(command.args))
            else
                panic("Unknown instruction: " .. command.instruction)
            end
        end
    end
end

-- Main
local args = { ... }

if not args[1] then
    print("Usage: asm <file>")
    return
end

local sourcePath = shell.resolve(args[1])

if not fs.exists(sourcePath) or fs.isDir(sourcePath) then
    print("File not found")
    return
end

local source <close> = fs.open(sourcePath, "r")

local lines = {}
for line in source:lines() do
    table.insert(lines, line)
end
source:close()

parseSource(lines)

-- Initialize registers and stack
for i = 0, registerSize - 1 do
    register[i] = 0
end

execute()
