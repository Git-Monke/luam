local SemVer = require ".luam.commands.install.semver"
local getPackage = require "commands.install.getpackage"

local pretty = require("cc.pretty")

--[[
    treeDir = the current nest structure
    package = Which module in the nest structure to look
    turns {"example", "path"} to example/luam_modules/path
    turns {"deep", "nested", "path"} to deep/luam_modules/nested/luam_modules/path
]]
local function treeDirToLockLocation(treeDir, package)
    if #treeDir == 0 then
        return package or ""
    end

    local result = treeDir[1]
    for i, path in ipairs(treeDir) do
        if i > 1 then
            result = result .. "/luam_modules/" .. path
        end
    end

    result = not package and result or result .. "/luam_modules/" .. package
    return result
end

local function splitByAtSymbol(str)
    local part1, part2 = str:match("([^@]*)@?(.*)")
    return part1, (part2 ~= "" and part2 or nil)
end

local function addToEnd(originalTable, value)
    local newTable = {}
    for i, v in ipairs(originalTable) do
        newTable[i] = v
    end
    table.insert(newTable, value)
    return newTable
end

local function metaToEntry(meta)
    return {
        name = meta.name,
        version = meta.version,
        dependencies = meta.dependencies
    }
end

local function firstN(tbl, n)
    local result = {}
    for i = 1, n do
        table.insert(result, tbl[i])
    end
    return result
end

local function addToDepTree(packageLOCK, depTree, treeDir, package, prefix)
    for i = 0, #treeDir do
        local cpath = treeDirToLockLocation(firstN(treeDir, i), package.name)

        if (packageLOCK[cpath] and SemVer.checkCompatability(packageLOCK[cpath].version, prefix .. package.version)) then
            return true;
        end

        if (depTree[cpath] and SemVer.checkCompatability(depTree[cpath].version, prefix .. package.version)) then
            return true
        end
    end

    local nestLevel = 0
    for i = 0, #treeDir do
        local cpath = treeDirToLockLocation(firstN(treeDir, i), package.name)

        if (not depTree[cpath] and not packageLOCK[cpath]) then
            nestLevel = i
            break
        end
    end

    -- * Download path
    local dpath = firstN(treeDir, nestLevel)
    depTree[treeDirToLockLocation(dpath, package.name)] = package
end

--[[
    query = a package query. Ex.
    package
    packge@0.1.0
    package@^0.1.5
    etc
]]
local function generateDepTree(packageLOCK, query, depTree, treeDir)
    local depTree = depTree or {}
    local treeDir = treeDir or {}

    local name, version = splitByAtSymbol(query)

    local prefix = SemVer.splitSemVer(version)
    local meta, code = getPackage(name, version, true)

    -- Super nesting. When more error codes are supported, this will look better.
    if code ~= 200 then
        if code == 404 then
            -- TODO: Allow users to link a github repository to their packages so users of faulty packages
            -- TODO: Can be redirected to them.
            error({
                message = { treeDirToLockLocation(treeDir) .. " depends on " .. query ..
                " which was unable to be found in the registry." }
            })
        end
    end

    local alreadyInstalled = addToDepTree(packageLOCK, depTree, treeDir, metaToEntry(meta), prefix)

    if alreadyInstalled then
        return
    end

    table.insert(treeDir, meta.name)
    for name, version in pairs(meta.dependencies) do
        generateDepTree(packageLOCK, name .. "@" .. version, depTree, treeDir)
    end
    table.remove(treeDir)

    return depTree
end

return generateDepTree
