require "commands.json"

local function init(args, path)
    local name;
    local type = "--exe"

    if (#args == 2) then
        name = args[2]
    else
        name = args[3]
        type = args[2]
    end

    if (type ~= "--lib" and type ~= "--exe" and type ~= "--both") then
        error({
            message = {"Package type specification must be one of three options",
                       "Correct usage: luam init [--lib|--exe|--both] <name>"}
        })
    end

    local dir = fs.combine(path or shell.dir(), name)

    fs.open(fs.combine(dir, "package.json"), "w").write('{\n  "package": {\n    "name": "' .. name ..
                                                            '",\n    "version": "0.1.0"\n  },\n  "dependencies": {}\n}')

    if (type ~= "--both") then
        local writer = fs.open(fs.combine(dir, type == "--lib" and "lib.lua" or (name .. ".lua")), "w")
        writer.write('require ".luam"\n\n')

        if (type == "--exe") then
            writer.write('print("Hello ' .. name .. '!")')
        else
            writer.write('return "Hello ' .. name .. '!"')
        end
    else
        local lib = fs.open(fs.combine(dir, "lib.lua"), "w");
        local main = fs.open(fs.combine(dir, name .. ".lua"), "w");
        lib.write('require ".luam"\n\n')
        lib.write('return "Hello ' .. name .. '!"')
        main.write('require ".luam"\n\n')
        main.write('local import = use("' .. name .. '")\n\n')
        main.write('print(import)')
    end
end

return init
