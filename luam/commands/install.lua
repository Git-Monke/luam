local ModuleTree = require "commands.install.moduletree"
local genDepTree = require "commands.install.gendeptree"
local getPackage = require "commands.install.getpackage"
local SemVer = require "commands.install.semver"

local pretty = require "cc.pretty"

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

local function install(args)
    if #args < 2 then
        error({
            message = {"At least 1 argument expected", "Correct usage: luam install <package>[@version]"}
        })
    end

    local pdir = findPackageDir()
    local tree = ModuleTree:new(pdir)
    local targetPackageName, targetPackageVersion = splitByAtSymbol(args[2])

    local successful, err = pcall(function()
        local depTree = genDepTree(tree.lock, args[2])

        if not depTree then
            print("Package already installed!")
            return;
        end

        -- A dependency tree being built means an existing version of the package we are trying to install must be incompatable with the user's query
        if tree.lock[targetPackageName] then
            local dependents = tree:findAllDependents(targetPackageName, tree.lock[targetPackageName].version)

            if #dependents == 0 then
                tree:deleteModule(targetPackageName)
            else
                tree:moveToTrash(targetPackageName)

                local existingInstallations = {}
                for _, dependent in ipairs(dependents) do
                    local alreadyInstalled = false;
                    for _, existingInstallation in ipairs(existingInstallations) do
                        if dependent.path:sub(1, #existingInstallation) == existingInstallation then
                            alreadyInstalled = true;
                            break
                        end
                    end

                    if not alreadyInstalled then
                        tree:copyFromTrash(targetPackageName, dependent.path .. "/luam_modules/" .. targetPackageName)
                        table.insert(existingInstallations, dependent.path)
                    end
                end
            end
        end

        local packageName, version = splitByAtSymbol(args[2])
        version = version or depTree[packageName].version

        local preExistingPackage = tree.lock[packageName]

        tree.package.dependencies[packageName] = version or "^" .. depTree[packageName].version

        for path, package in pairs(depTree) do
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
