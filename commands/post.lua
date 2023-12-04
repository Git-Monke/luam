local pretty = require "cc.pretty"

local function mergeTables(t1, t2)
    for k, v in pairs(t2) do
        t1[k] = v
    end
end

local function processDir(path, relPath)
    local files = fs.list(path)
    local package = {}

    for _, file in ipairs(files) do
        local absPath = fs.combine(path, file)

        if fs.isDir(absPath) then
            if absPath:sub(-12) ~= "luam_modules" then
                mergeTables(package, processDir(absPath, file))
            end
        else
            local reader = fs.open(absPath, "r")
            package[fs.combine(relPath, file)] = reader.readAll()
            reader.close()
        end
    end

    return package
end

local function post(args)
    local path = args[2] or shell.dir()

    if (not fs.isDir(path)) then
        error({
            message = {"Invalid directory!"}
        })
    end

    if (not fs.exists("luam.key")) then
        error({
            message = {"Must be logged in to post package", "Run luam help signup or luam help login for more info"}
        })
    end

    if (not fs.exists(fs.combine(path, "package.json"))) then
        error({
            message = {"A package.json is required to upload a package to the registry."}
        })
    end

    local reader = fs.open("luam.key", "r")
    local authKey = reader.readAll()
    reader.close()

    local package = processDir(path, "");

    local body = {
        data = package,
        authKey = authKey
    }

    local response, errMessage, failedResponse = http.post("http://localhost:3000/packages",
        textutils.serialiseJSON(body), {
            ["Content-Type"] = "application/json"
        })

    if (errMessage) then
        error({
            message = {failedResponse.getResponseCode() .. " " ..
                textutils.unserialiseJSON(failedResponse.readAll()).message}
        })
    end

    print("Package posted to registry successfully!")
end

return post
