require "commands.json"

local pretty = require "cc.pretty"

local function splitSemVer(ver)
    local major, minor, patch = ver:match("(%d+)%.(%d+)%.(%d+)")
    return major, minor, patch
end

local function toSemVer(ma, mi, pa)
    return ma .. "." .. mi .. "." .. pa
end

local function open()
    local dir = shell.dir()
    local path = fs.combine(dir, "package.json")
    if not fs.exists(path) then
        error({
            message = {"No package.json found in directory"}
        })
    end
    return decodeFromFile(path)
end

local function write(package)
    local writer = fs.open(fs.combine(shell.dir(), "package.json"), "w")
    writer.write(encodePretty(package))
    writer.close()
end

local function patch(args)
    local data = open()
    local package = data.package
    local ma, mi, pa = splitSemVer(package.version)
    package.version = toSemVer(ma, mi, pa + 1)
    print("Updated to " .. package.version)
    write(data)
end

local function minor(args)
    local data = open()
    local package = data.package
    local ma, mi, pa = splitSemVer(package.version)
    package.version = toSemVer(ma, mi + 1, 0)
    print("Updated to " .. package.version)
    write(data)
end

local function major(args)
    local data = open()
    local package = data.package
    local ma, mi, pa = splitSemVer(package.version)
    package.version = toSemVer(ma + 1, 0, 0)
    print("Updated to " .. package.version)
    write(data)
end

return {
    patch = patch,
    minor = minor,
    major = major
}
