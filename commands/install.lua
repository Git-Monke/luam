local ModuleTree = require "commands.install.moduletree"
local genDepTree = require "commands.install.gendeptree"
local getPackage = require "commands.install.getpackage"
local SemVer = require ".luam.commands.install.semver"

local pretty = require "cc.pretty"

-- TODO: Refactor such that all split operations use this function or something similar.
-- TODO: Right now there are 3 functions that all perform almost the same task.
local function split(str, delimiter)
    delimiter = delimiter or " "
    local result = {}
    local pattern = "(.-)" .. delimiter
    local lastEnd = 1
    local s, e, cap = str:find(pattern, 1)
    while s do
        if s ~= 1 or cap ~= "" then
            table.insert(result, cap)
        end
        lastEnd = e + 1
        s, e, cap = str:find(pattern, lastEnd)
    end
    if lastEnd <= #str then
        cap = str:sub(lastEnd)
        table.insert(result, cap)
    end
    return result
end

local function splitByAtSymbol(str)
    local part1, part2 = str:match("([^@]*)@?(.*)")
    return part1, (part2 ~= "" and part2 or nil)
end

local function splitPath(path)
    local parts = {}
    for part in string.gmatch(path, "([^/]+)") do
        table.insert(parts, part)
    end
    return parts
end

local function asPath(parts)
    return table.concat(parts, "/")
end

local function findPackageDir()
    local wdir = shell.dir()
    local components = splitPath(wdir)

    while not fs.exists(fs.combine(asPath(components), "package.json")) and #components > 0 do
        table.remove(components)
    end

    if #components == 0 then
        return shell.dir()
    end

    return asPath(components)
end

local function installedInHigherDir(dependent, existingInstallations)
    for _, existingInstallation in ipairs(existingInstallations) do
        if dependent.path:sub(1, #existingInstallation) == existingInstallation then
            return true
        end
    end
    return false
end

local function reinstallSubmodules(tree, path, submodules)
    for subPath, data in pairs(submodules) do
        -- Ensure that the nest is nested inside of the submodule we are installing into
        local nest = split(path .. "/luam_modules/" .. subPath, "/luam_modules/")

        local needToInstall, installLocation = tree:findInstallationLocation(nest, data.name, data.version)
        if needToInstall then
            tree:copyFromTrashExcludingSubmodules(subPath, installLocation)
        end
    end
end

local function install(args)
    if #args < 2 then
        error({
            message = { "At least 1 argument expected", "Correct usage: luam install <package>[@version]" }
        })
    end

    local pdir = findPackageDir()
    local tree = ModuleTree:new(pdir)
    local targetPackageName, targetPackageVersion = splitByAtSymbol(args[2])

    local successful, err = pcall(function()
        if not targetPackageVersion then
            local meta = getPackage(targetPackageName, nil, true)
            targetPackageVersion = meta.version
        end

        if tree.lock[targetPackageName] and
            SemVer.checkCompatability(tree.lock[targetPackageName].version, targetPackageVersion) then
            print("A compatible version is already installed!")
            print('If youd like to update, run "luam update".')
            return;
        end

        -- A dependency tree being built means an existing version of the package we are trying to install must be incompatable with the user's query
        if tree.lock[targetPackageName] then
            local dependents = tree:findAllDependents(targetPackageName, tree.lock[targetPackageName].version)

            if #dependents == 0 then
                tree:deleteModule(targetPackageName)
            else
                local submodules = {}
                local search = targetPackageName .. "/"

                for path, data in pairs(tree.lock) do
                    if path:sub(1, #search) == search then
                        submodules[path] = data
                    end
                end

                tree:moveToTrash(targetPackageName)

                local existingInstallations = {}
                for _, dependent in ipairs(dependents) do
                    local installLocation = dependent.path .. "/luam_modules/" .. targetPackageName
                    if not installedInHigherDir(dependent, existingInstallations) and not tree.lock[installLocation] then
                        tree:copyFromTrashExcludingSubmodules(targetPackageName, installLocation)

                        reinstallSubmodules(tree, dependent.path, submodules)

                        table.insert(existingInstallations, dependent.path)
                    end
                end
            end
        end

        local depTree = genDepTree(tree.lock, args[2])

        local packageName, version = splitByAtSymbol(args[2])
        version = version or depTree[packageName].version

        local preExistingPackage = tree.lock[packageName]

        tree.package.dependencies[packageName] = version or ("^" .. depTree[packageName].version)

        for path, package in pairs(depTree) do
            print("Installing " .. path .. " v" .. package.version)
            tree:installModule(path, package.name, package.version)
        end
    end)

    if successful then
        tree:commitChanges()
    else
        tree:revertChanges()
        error(err)
    end
end

return install
