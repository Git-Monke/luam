local function init(args)
    local name;
    local type = "--exe"

    if (#args == 2) then
        name = args[2]
    else
        name = args[3]
        type = args[2]
    end

    if (type ~= "--lib" and type ~= "--exe") then
        error({
            message = {"Package type specification must be one of three options",
                       "Correct usage: luam init [--lib|--exe|--both] <name>"}
        })
    end

    local dir = fs.combine(shell.dir(), name)

    fs.open(fs.combine(dir, "luam.toml"), "w").write('[package]\nname = "' .. name ..
                                                         '"\nversion = "0.1.0"\n\n[dependencies]\n')

    if (type ~= "--both") then
        local writer = fs.open(fs.combine(dir, type == "--lib" and "init.lua" or "main.lua"), "w")
        writer.write('print("Hello New ' .. (type == "--lib" and "Library" or "Executable") .. '!")')
    else
        local lib = fs.open(fs.combine(dir, "lib.lua"), "w");
        local main = fs.open(fs.combine(dir, "main.lua"), "w");
        lib.write('print("Hello New Library!")')
        main.write('print("Hello New Executable!")')
    end
end

return init
