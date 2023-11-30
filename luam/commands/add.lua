require "commands.json"
local pretty = require "cc.pretty"

local function splitByAtSymbol(s)
    local name, version = s:match("([^@]+)@?(.*)")
    return name, version
end

local function extractAfterN(table, n)
    local result = {}
    for i = n + 1, #table do
        result[#result + 1] = table[i]
    end
    return result
end

local function contains(table, item)
    for _, value in pairs(table) do
        if value == item then
            return true
        end
    end
    return false
end

local function alreadySemver(str)
    return str:sub(1, 1) == "^" or str:sub(1, 1) == "~"
end

local function add(args, path)
    path = path or shell.dir()

    if (not args[2]) then
        error({
            message = {"A package name is required", "Correct usage: luam <name>[@version]",
                       "Run luam help add for more details"}
        })
    end

    local flags = extractAfterN(args, 2)
    local exact = flags[1] == "--exact" or flags[1] == "--e"
    local patch = flags[1] == "--patch-only" or flags[1] == "--po"

    local packageJSONPath = fs.combine(path, "package.json")

    if not fs.exists(packageJSONPath) then
        error({
            message = {"A package.json is required to download a dependency."}
        })
    end

    local packageName, version = splitByAtSymbol(args[2])
    local versionParam = version and ("?version=" .. version) or ""

    local handler, errMessage, failedResponse = http.get("http://localhost:3000/packages/" .. packageName ..
                                                             versionParam)

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

    -- * Extract necessary package information

    local data = textutils.unserialiseJSON(handler.readAll())
    local package = data.package
    local main = data.main or "main.lua"

    -- * Update the package.json to include the new dependency

    local packageJSON = decodeFromFile(packageJSONPath)

    if packageJSON.dependencies[packageName] then
        fs.delete(fs.combine(path, "luam_modules/" .. packageName))
    end

    local prefix = (alreadySemver(version) or exact) and "" or (patch and "~" or "^")

    packageJSON.dependencies[packageName] = prefix .. (version ~= "" and version or data.version)

    local writer = fs.open(packageJSONPath, "w")
    writer.write(encodePretty(packageJSON))
    writer.close()

    -- * Install all dependencies

    if (data.dependencies) then
        for name, version in pairs(data.dependencies) do
            add({"add", name .. "@" .. version}, fs.combine(path, packageName .. "/node_modules"))
        end
    end

    -- * Install package itself

    for key, value in pairs(package) do
        if key ~= "package.json" then
            local installPath = fs.combine(path, "luam_modules/" .. fs.combine(data.name, key))

            print("Installing " .. key)
            local writer = fs.open(installPath, "w")
            writer.write(value)
            writer.close()
        end
    end

    print("Installation complete")
end

return add
