require ".luam.commands.json"
local pretty = require "cc.pretty"

local function splitByDelimiter(str, delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = str:find(delimiter, from)
    while delim_from do
        table.insert(result, str:sub(from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = str:find(delimiter, from)
    end
    table.insert(result, str:sub(from))
    return result
end

local function parseDepTree(path)
    local json = decodeFromFile(path)

    for key, package in pairs(json) do

        if key:find("luam_modules") then
            local path = splitByDelimiter(key, "/luam_modules/")
            local target = json[path[1]]

            for i = 2, #package - 1 do
                target = target.nest[path[i]]
            end

            target.nest[path[#path]] = package
            json[key] = nil
        else
            package["nest"] = {}
        end
    end

    return json
end

return parseDepTree
