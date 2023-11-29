local function install(args)
    if (not args[2]) then
        error({
            message = {"A package name is required", "Correct usage: luam <name> [version]"}
        })
    end

    local version = args[3] and ("?version=" .. args[3]) or ""

    local handler, errMessage, failedResponse = http.get("http://localhost:3000/packages/" .. args[2] .. version)

    if (errMessage) then
        error({
            message = {failedResponse.getResponseCode() .. " " ..
                textutils.unserialiseJSON(failedResponse.readAll()).message}
        })
    end

    local data = textutils.unserialiseJSON(handler.readAll())
    local package = data.package
    local main = data.main or "main.lua"

    if (data.dependencies) then
        for name, version in pairs(data.dependencies) do
            install({"install", name, version})
        end
    end

    for key, value in pairs(package) do
        local installPath = "packages/" .. data.name .. "/" .. key .. ""

        if (key == main) then
            installPath = "executables/" .. data.name .. ".lua"
        end

        print("Installing " .. key)
        local writer = fs.open(installPath, "w")

        if (key == main) then
            writer.write('-- Automagically inserted by luam!\npackage.path = "/packages/' .. data.name ..
                             '/?.lua;" .. package.path\n\n')
        end

        writer.write(value)

        writer.close()
    end

    print("Installation complete")
end

return install