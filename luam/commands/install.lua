local init = require "commands.init"
local add = require "commands.add"

local pretty = require "cc.pretty"

local function splitByAtSymbol(s)
    local name, version = s:match("([^@]+)@?(.*)")
    return name, (version ~= "" and version or nil)
end

local function promptYesNo(message)
    while true do
        print(message .. " (y/n)")
        local input = string.lower(read())
        if input == "y" then
            return true
        elseif input == "n" then
            return false
        end
    end
end

local function cleanString(str)
    str = str:match("^%s*(.-)%s*$")
    return (str:gsub("[%c%s]", ""))
end

local function scanForPath(path)
    if not fs.exists("startup.lua") then
        return false
    end

    local target = 'shell.setPath(shell.path() .. ":" .. "/' .. path .. '")'

    for line in io.lines("startup.lua") do
        if line == target then
            return true
        end
    end

    return false
end

local function install(args)
    if #args < 2 then
        error({
            message = {"At least two arguments expected!", "Correct usage: luam install <name> [directory]"}
        })
    end

    local name, version = splitByAtSymbol(args[2])
    version = version and ("?version=" .. version) or ""

    local dir = ""
    local safe = true

    if #args == 3 then
        dir = args[3]
    end

    local path = fs.combine(dir, name)

    if fs.exists(path) then
        if not promptYesNo("It appears that " .. path ..
                               " already exists. This installation will overwrite it. Proceed anyway?") then
            return;
        end
    end

    -- * Install the program

    local handler, errMessage, failedResponse = http.get("http://localhost:3000/packages/" .. name .. version)

    if (errMessage) then
        if not failedResponse then
            error({
                message = {"Server is down. Please try again later!"}
            })
        end

        error({
            message = {failedResponse.getResponseCode() .. " " ..
                textutils.unserialiseJSON(failedResponse.readAll()).message}
        })
    end

    fs.delete(path)

    -- * Extract necessary package information

    local data = textutils.unserialiseJSON(handler.readAll())
    local package = data.package
    local dependencies = data.dependencies

    init({"init", "--exe", name}, dir)

    -- * Add all dependencies

    if (data.dependencies) then
        for depName, version in pairs(data.dependencies) do
            add({"add", depName .. "@" .. version}, path)
        end
    end

    -- * Install package itself

    for key, value in pairs(package) do
        if key ~= "package.json" then
            local installPath = fs.combine(path, key)
            print("Installing " .. key)
            local writer = fs.open(installPath, "w")
            writer.write(value)
            writer.close()
        end
    end

    if scanForPath(path) then
        return
    end

    if (promptYesNo("Add to PATH?")) then
        shell.setPath(shell.path() .. ":" .. path)
        local writer = fs.open("startup.lua", "a")
        writer.write('\nshell.setPath(shell.path() .. ":" .. "/' .. path .. '")')
        writer.close()
    end
end

return install
