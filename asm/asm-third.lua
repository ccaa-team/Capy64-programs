local fs = require("fs")
local event = require("event")
local timer = require("timer")

local memorySize = 512

local function panic(msg)
    error(msg, 0)
end

local function int(x)
    --return math.tointeger(x) & 0xffffffff
    return x
end

local memory = {}

local function getRam(key)
    if type(key) ~= "number" then
        panic("number expected")
    end

    if key < 0 or key >= memorySize then
        panic("Memory address overflow")
    end

    return memory[key]
end

local function setRam(key, value)
    if type(key) ~= "number" then
        panic("number expected")
    end

    if key < 0 or key >= memorySize then
        panic("Memory address overflow")
    end

    memory[key] = int(value)
end

for i = 0, memorySize - 1 do
    memory[i] = 0
end

local flags = {
    zero = false,
    carry = false,
    overflow = false,
    negative = false,
    eq = false,
    lt = false,
    gt = false,
}

local dynRegister = {
    zero = {
        get = function()
            return 0
        end,
        set = function(value)
        end,
    },
    carry = {
        get = function()
            return flags.carry and 1 or 0
        end,
        set = function(value)
            flags.carry = value ~= 0
        end,
    },
    overflow = {
        get = function()
            return flags.overflow and 1 or 0
        end,
        set = function(value)
            flags.overflow = value ~= 0
        end,
    },
    negative = {
        get = function()
            return flags.negative and 1 or 0
        end,
        set = function(value)
            flags.negative = value ~= 0
        end,
    },
    eq = {
        get = function()
            return flags.eq and 1 or 0
        end,
        set = function(value)
            flags.eq = value ~= 0
        end,
    },
    lt = {
        get = function()
            return flags.lt and 1 or 0
        end,
        set = function(value)
            flags.lt = value ~= 0
        end,
    },
    gt = {
        get = function()
            return flags.gt and 1 or 0
        end,
        set = function(value)
            flags.gt = value ~= 0
        end,
    },
}

local register = {
    r0 = 0,
    r1 = 0,
    r2 = 0,
    r3 = 0,
    r4 = 0,
    r5 = 0,
    r6 = 0,
    r7 = 0,
    r8 = 0,
    r9 = 0,
    r10 = 0,
    r11 = 0,
    r12 = 0,
    r13 = 0,
    r14 = 0,
    r15 = 0,
}

-- x = n
local aliases = {}

local function hasReg(reg)
    return (dynRegister[reg] or register[reg]) ~= nil
end

local function setReg(reg, value)
    reg = reg:lower()
    if dynRegister[reg] then
        dynRegister[reg].set(value)
        return
    end

    if register[reg] then
        register[reg] = int(value)
        return
    end

    panic("invalid register")
end

local function getReg(reg)
    reg = reg:lower()
    if dynRegister[reg] then
        return dynRegister[reg].get()
    end
    if register[reg] then
        return register[reg]
    end
    panic("invalid register")
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
        panic("Invalid value")
    end
    return output
end

local function getValue(src)
    local address = src:match("^%[(.-)%]$")
    if address then
        local regValue = getValue(address)
        return getRam(regValue)
    end
    if hasReg(src) then
        return getReg(src)
    end
    if aliases[src] then
        return getValue(aliases[src])
    end
    return resolveNumber(src)
end

local function setValue(to, src)
    if type(src) == "number" then
        src = tostring(src)
    end
    local value = getValue(src)
    local address = to:match("^%[(.-)%]$")
    if address then
        local regValue = getValue(address)
        setRam(regValue, value)
        return
    end
    if hasReg(to) then
        return setReg(to, value)
    end
    if aliases[to] then
        return setValue(aliases[to], src)
    end
    panic("invalid address")
end

local currentLine = 0
local exit = false
local program = {}
local labels = {}

local function jump(label)
    if labels[label] then
        currentLine = labels[label]
    else
        panic("Invalid label")
    end
end

local instructions = {}

-- Instructions

function instructions.out(...)
    local out = {}
    for i = 1, select("#", ...) do
        local value = getValue(select(i, ...))
        table.insert(out, value)
    end
    print(table.unpack(out))
end

function instructions.mov(address, value)
    if not address then
        panic("Missing address")
    end
    if not value then
        panic("Missing value")
    end
    setValue(address, value)
end

function instructions.hlt()
    exit = true
end

function instructions.slp(time)
    if not time then
        panic("Missing time")
    end
    time = getValue(time)
    timer.sleep(time)
end

function instructions.nop()
    event.push("nop")
    event.pull("nop")
end

function instructions.als(alias, value)
    if not alias then
        panic("Missing alias")
    end
    if not value then
        panic("Missing value")
    end
    aliases[alias] = value
end

function instructions.jmp(label)
    if not label then
        panic("Missing label")
    end
    jump(label)
end

function instructions.add(a, b)
    if not a then
        panic("Missing a")
    end
    if not b then
        panic("Missing b")
    end
    local value = getValue(a) + getValue(b)
    setValue(a, value)
end

function instructions.sub(a, b)
    if not a then
        panic("Missing a")
    end
    if not b then
        panic("Missing b")
    end
    local value = getValue(a) - getValue(b)
    setValue(a, value)
end

function instructions.mul(a, b)
    if not a then
        panic("Missing a")
    end
    if not b then
        panic("Missing b")
    end
    local value = getValue(a) * getValue(b)
    setValue(a, value)
end

function instructions.div(a, b)
    if not a then
        panic("Missing a")
    end
    if not b then
        panic("Missing b")
    end
    local value = getValue(a) / getValue(b)
    setValue(a, value)
end

function instructions.idiv(a, b)
    if not a then
        panic("Missing a")
    end
    if not b then
        panic("Missing b")
    end
    local value = math.floor(getValue(a) // getValue(b))
    setValue(a, value)
end

function instructions.mod(a, b)
    if not a then
        panic("Missing a")
    end
    if not b then
        panic("Missing b")
    end
    local value = getValue(a) % getValue(b)
    setValue(a, value)
end

function instructions.pow(a, b)
    if not a then
        panic("Missing a")
    end
    if not b then
        panic("Missing b")
    end
    local value = getValue(a) ^ getValue(b)
    setValue(a, value)
end

function instructions.sqrt(a)
    if not a then
        panic("Missing a")
    end
    local value = math.sqrt(getValue(a))
    setValue(a, value)
end

function instructions.inc(a)
    if not a then
        panic("Missing a")
    end
    local value = getValue(a) + 1
    setValue(a, value)
end

function instructions.dec(a)
    if not a then
        panic("Missing a")
    end
    local value = getValue(a) - 1
    setValue(a, value)
end

-- Branching

function instructions.cmp(a, b)
    if not a then
        panic("Missing a")
    end
    if not b then
        panic("Missing b")
    end
    local valueA = getValue(a)
    local valueB = getValue(b)
    flags.eq = valueA == valueB
    flags.lt = valueA < valueB
    flags.gt = valueA > valueB
end

function instructions.je(label)
    if not label then
        panic("Missing label")
    end
    if flags.eq then
        jump(label)
    end
end

function instructions.jne(label)
    if not label then
        panic("Missing label")
    end
    if not flags.eq then
        jump(label)
    end
end

function instructions.jl(label)
    if not label then
        panic("Missing label")
    end
    if flags.lt then
        jump(label)
    end
end

function instructions.jle(label)
    if not label then
        panic("Missing label")
    end
    if flags.lt or flags.eq then
        jump(label)
    end
end

function instructions.jg(label)
    if not label then
        panic("Missing label")
    end
    if flags.gt then
        jump(label)
    end
end

function instructions.jge(label)
    if not label then
        panic("Missing label")
    end
    if flags.gt or flags.eq then
        jump(label)
    end
end

-- Bitwise

instructions["and"] = function(a, b)
    if not a then
        panic("Missing a")
    end
    if not b then
        panic("Missing b")
    end
    local value = getValue(a) & getValue(b)
    setValue(a, value)
end

instructions["or"] = function(a, b)
    if not a then
        panic("Missing a")
    end
    if not b then
        panic("Missing b")
    end
    local value = getValue(a) | getValue(b)
    setValue(a, value)
end

function instructions.xor(a, b)
    if not a then
        panic("Missing a")
    end
    if not b then
        panic("Missing b")
    end
    local value = getValue(a) ~ getValue(b)
    setValue(a, value)
end

instructions["not"] = function(a)
    if not a then
        panic("Missing a")
    end
    local value = ~getValue(a)
    setValue(a, value)
end

function instructions.shl(a, b)
    if not a then
        panic("Missing a")
    end
    if not b then
        panic("Missing b")
    end
    local value = getValue(a) << getValue(b)
    setValue(a, value)
end

function instructions.shr(a, b)
    if not a then
        panic("Missing a")
    end
    if not b then
        panic("Missing b")
    end
    local value = getValue(a) >> getValue(b)
    setValue(a, value)
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
            if command.type == "label" then
                labels[command.name] = #program + 1
            end
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
                error("Unknown instruction: " .. command.instruction, 0)
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
local ok, err = pcall(execute)
if not ok then
    local command = program[currentLine]
    print(string.format("Line %d: %s\n%s", command.sourcePosition, command.sourceLine, err))
end
