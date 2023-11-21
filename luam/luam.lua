os.loadAPI("luam/Result.lua")

local args = {...}

-- function recursive_print(input, depth)
--     depth = depth or 0
--     for key, entry in pairs(input) do
--         if type(entry) == "table" then
--             print(string.rep(" ", depth) .. key)
--             recursive_print(entry, depth + 1)
--         else
--             print(string.rep(" ", depth) .. key)
--         end
--     end
-- end
-- Takes in a path and converts it to absolute given the current shell directory. If it's already absolute, leave it alone.
-- Can only error if no path is provided
function normalize_path(path)
    if not path then
        return Result.Err("No path provided")
    end
    
    if not (string.sub(path, 1, 1) == "/") then
        path = fs.combine(shell.dir(), path)
    end
    
    return Result.Ok(path)
end

function build_package(dir)
    if not dir then
        return Result.Err("No directory provided")
    end
    
    if not fs.isDir(dir) then
        return Result.Err("Not a valid directory!")
    end
    
    local found_toml = false
    local files = fs.list(dir)
    local output = {}
    
    for _, file in pairs(files) do
        local path = dir .. "/" .. file
        local result
        
        if file == "luam.toml" then
            found_toml = true
        end
        
        if fs.isDir(path) then
            result = build_package(path):unwrap_or_error()
            
            for subpath, contents in pairs(result) do
                output[subpath] = contents
            end
        else
            local reader = fs.open(path, "r")
            output[path] = reader.readAll()
            reader.close()
        end
    end
    
    if not found_toml then
        return Result.Err("No toml file found!")
    end
    
    return Result.Ok(output)
end

function run_build(dir)
    local result = build_package(dir):unwrap_or_error()
    local output = textutils.serialise(result, nil, 4)
    
    local writer = fs.open("output.txt", "w")
    writer.write(output)
    writer.close()
end

function init_project(name)
    local current_path = shell.dir()
    
    local project_path = fs.combine(current_path, name)
    fs.makeDir(project_path)
    
    local toml = fs.open(fs.combine(project_path, "luam.toml"), "w")
    toml.write('[package]\nname = "' .. name .. '"\nversion = "0.1.0"\n\n[dependencies]')
    toml.close()
    
    local src = fs.open(fs.combine(project_path, "src.lua"), "w")
    src.write('print("Hello World!")')
    src.close()
    
    print("New project created at " .. project_path)
end

if not args[1] then
    error("At least one argument expected. Example usage:\n  luam <command> <arguments>")
end

if args[1] == "build" then
    local path = normalize_path(args[2]):unwrap_or_error()
    run_build(path)
    return
end

if args[1] == "init" then
    local name = args[2] or error("No package name included!")
    init_project(name)
    return
end

error("Invalid command")
