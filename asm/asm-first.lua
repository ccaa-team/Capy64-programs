local io = require("io")
local timer = require("timer")
local fs = require("fs")
local audio = require("audio")

local Stack = {}
Stack.__index = {
    pop = function(self, n)
        n = tonumber(n)
        for i = 1, n or 1 do
            table.remove(self)
        end
    end,
    push = function(self, v)
        local value = v
        if type(value) == "string" then
            value = string.byte(value)
        end
        table.insert(self, value)
    end,
    getIndex = function(self, index)
        index = tonumber(index)
        if index >= 0 then
            return index
        end

        return #self + (index + 1)
    end,
    get = function(self, index)
        if index == 0 then
            return 0
        end
        return self[self:getIndex(index)]
    end
}

local register = {}
local registerSize = 16
for i = 0, registerSize - 1 do
    register[i] = 0
end

local program = {}
local currentLine = 0

local exit = false
local function panic(msg)
    exit = true
    local cmd = program[currentLine]
    print(string.format("Line %d: %s\n%s", cmd.lineNumber, cmd.line, msg))
end

local stack = setmetatable({}, Stack)

local function number(val)
    val = val:gsub("_", "")
    if val:sub(1, 2) == "0x" then
        return tonumber(val:sub(3), 16)
    end
    return tonumber(val)
end

local function get(key)
    if key == "nul" then
        return 0
    end
    if key:sub(1, 1) == "$" then
        local index = number(key:sub(2))
        if index >= registerSize or index < 0 then
            panic("Register index out of bounds")
        end
        return register[index]
    elseif key:sub(1, 1) == "%" then
        return stack:get(key:sub(2))
    else
        -- it's a raw value
        return number(key)
    end
end

local function set(key, value)
    if key == "nul" then
        return
    end
    value = get(value)
    if key:sub(1, 1) == "$" then
        local index = number(key:sub(2))
        if index >= registerSize or index < 0 then
            panic("Register index out of bounds")
        end
        register[number(key:sub(2))] = value
    end
end

local instructions = {}
function instructions.pop(n)
    n = number(n)
    stack:pop(n)
end

function instructions.psh(value)
    value = get(value)
    if not value then
        panic("Value is not a number")
    end
    stack:push(value)
end

function instructions.mov(addr, value)
    set(addr, value)
end

function instructions.cpy(index)
    index = get(index)
    stack:push(stack:get(index))
end

function instructions.prt(val)
    val = get(val)
    print(val)
end

function instructions.prtc(index)
    index = get(index)
    local value = stack[index]
    io.write(value and string.char(value % 256) or "")
end

function instructions.pshs(val)
    local len = #val
    stack:push(len)
    for i = 1, len do
        stack:push(string.sub(val, i, i))
    end
end

function instructions.prts(index)
    index = number(index)
    local len = stack:get(index)
    local index = stack:getIndex(index)
    for i = index + 1, len + index do
        instructions.prtc(i)
    end
end

function instructions.jmp(flag)
    for i = 1, #program do
        local cmd = program[i]
        if cmd.type == "flag" and cmd.flag == flag then
            currentLine = i - 1
            return
        end
    end
    panic("Unknown flag " .. flag)
end

function instructions.ife(a, b, flag)
    a = get(a)
    b = get(b)
    if a == b then
        instructions.jmp(flag)
    end
end

function instructions.ifn(a, b, flag)
    a = get(a)
    b = get(b)
    if a ~= b then
        instructions.jmp(flag)
    end
end

function instructions.ifg(a, b, flag)
    a = get(a)
    b = get(b)
    if a > b then
        instructions.jmp(flag)
    end
end

function instructions.ifge(a, b, flag)
    a = get(a)
    b = get(b)
    if a >= b then
        instructions.jmp(flag)
    end
end

function instructions.ifl(a, b, flag)
    a = get(a)
    b = get(b)
    if a < b then
        instructions.jmp(flag)
    end
end

function instructions.ifle(a, b, flag)
    a = get(a)
    b = get(b)
    if a <= b then
        instructions.jmp(flag)
    end
end

function instructions.sum()
    local a = stack:get(-2)
    local b = stack:get(-1)
    stack:pop(2)
    stack:push(a + b)
end

function instructions.sub()
    local a = stack:get(-2)
    local b = stack:get(-1)
    stack:pop(2)
    stack:push(a - b)
end

function instructions.mul()
    local a = stack:get(-2)
    local b = stack:get(-1)
    stack:pop(2)
    stack:push(a * b)
end

function instructions.div()
    local a = stack:get(-2)
    local b = stack:get(-1)
    stack:pop(2)
    stack:push(a / b)
end

function instructions.idiv()
    local a = stack:get(-2)
    local b = stack:get(-1)
    stack:pop(2)
    stack:push(a // b)
end

function instructions.mod()
    local a = stack:get(-2)
    local b = stack:get(-1)
    stack:pop(2)
    stack:push(a * b)
end

function instructions.slp(time)
    time = get(time)
    timer.sleep(time)
end

instructions["end"] = function()
    error()
end

local function dumpStack()
    for k, v in ipairs(stack) do
        local ok, ch = pcall(string.char, v % 256)
        print("%" .. k .. ": ", v, "(" .. (ok and ch or "nil") .. ")")
    end
end

local function dumpRegister()
    for k = 0, registerSize - 1 do
        local v = register[k]
        local ok, ch = pcall(string.char, v % 256)
        print("$" .. k .. ": ", v, "(" .. (ok and ch or "nil") .. ")")
    end
end

function instructions.dmp()
    dumpStack()
    dumpRegister()
end

local function parseCommand(command, lineNumber)
    local seg = {}
    for w in command:gmatch("%S+") do
        table.insert(seg, w)
    end

    local ins = table.remove(seg, 1)

    if ins:sub(#ins, #ins) == ":" then
        return {
            type = "flag",
            flag = ins:sub(1, #ins - 1),
            line = command,
            lineNumber = lineNumber,
        }
    end

    return {
        type = "instruction",
        instruction = ins,
        args = seg,
        line = command,
        lineNumber = lineNumber,
    }
end

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

local source<close> = fs.open(sourcePath, "r")

local lineN = 1
for line in source:lines() do
    line = line:match("^%s*(.-)%s*$")
    if line:sub(1, 1) ~= ";" and line ~= "" then
        line = line:match("^%s*(.-)%s*;?$")
        local c = parseCommand(line, lineN)
        table.insert(program, c)
    end
    lineN = lineN + 1
end

source:close()

while not exit and currentLine < #program do
    currentLine = currentLine + 1

    local cmd = program[currentLine]
    if cmd.type == "instruction" then
        if not instructions[cmd.instruction] then
            return panic("Invalid instruction " .. cmd.instruction)
        end
        instructions[cmd.instruction](table.unpack(cmd.args))
    end
end
