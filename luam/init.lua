local function firstN(tbl, n)
    local result = {}
    for i = 1, n do
        table.insert(result, tbl[i])
    end
    return result
end

local function split(string, sep)
    sep = sep or " "
    local t = {}
    for substr in string.gmatch(string, "([^" .. sep .. "]+)") do
        table.insert(t, substr)
    end
    return t
end

local function mergeFileTables(t1, t2)
    return table.concat(t1, "/") .. "/" .. table.concat(t2, "/")
end

function use(path)
    local absPath = split(debug.getinfo(2, "S").source:sub(2), "/")
    table.remove(absPath)

    path = split(path, "/")

    local finalPath;

    if (path[1] == ".") then
        table.remove(path, 1)

        finalPath = mergeFileTables(absPath, path)
    elseif (path[1] == "..") then
        local upDirs = 0

        while path[1] == ".." do
            upDirs = upDirs + 1;
            table.remove(path, 1)
        end

        if (upDirs > #absPath) then
            error("Cannot move up more directories than exists")
        end

        local root = firstN(absPath, #absPath - upDirs)

        finalPath = mergeFileTables(root, path)
    else
        if absPath[#absPath] == path[1] then
            finalPath = mergeFileTables(absPath, {"lib.lua"})
        else
            while #absPath > 0 do
                local tempPath = table.concat(absPath, "/")
                local dirs = fs.list(tempPath)
                local foundModules = false;

                for _, dir in ipairs(dirs) do
                    if dir == "luam_modules" then
                        foundModules = true;
                    end
                end

                if foundModules then
                    local modulesPath = fs.combine(tempPath, "luam_modules")
                    local files = fs.list(modulesPath)

                    if fs.exists(fs.combine(modulesPath .. "/" .. path[1] .. "/" .. "lib.lua")) then
                        break
                    end
                end

                table.remove(absPath)
            end

            if (#absPath == 0) then
                error("Could not find " .. path)
            end

            local packPath = {"luam_modules", path[1], "lib.lua"}

            finalPath = mergeFileTables(absPath, packPath)
        end
    end

    local preserved = finalPath
    finalPath = finalPath:gsub("/", ".")
    finalPath = finalPath:gsub("%.lua$", "")
    local success, result = pcall(require, "." .. finalPath)

    if not success then
        error("Could not find " .. preserved)
    end

    return result
end
