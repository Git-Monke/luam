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

    pretty.pretty_print(tree:findAllDependents("b", "^0.1.0"))

    local successful, err = pcall(function()
        local depTree = genDepTree(tree.lock, args[2])

        if not depTree then
            print("Package already installed!")
            return;
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
