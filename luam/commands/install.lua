require ".luam.commands.json"

local pretty = require "cc.pretty"
local SemVer = require ".luam.commands.utils.semver"
local areCompatible = SemVer.checkCompatability
local splitSemVer = SemVer.splitSemVer

local function sortAlphabetically(tbl)
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys)
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], tbl[keys[i]]
        end
    end
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

local function getPackageMeta(name, version)
    version = version and "?version=" .. version or ""
    local meta = (version ~= "" and "&" or "?") .. "meta=true"

    local handler, errMessage, failedResponse = http.get("http://localhost:3000/packages/" .. name .. version .. meta)

    if (errMessage) then
        if not failedResponse then
            error({
                message = {"Server is down. Please try again later!"}
            })
        end

        error({
            message = {failedResponse.getResponseCode() .. " " ..
                textutils.unserialiseJSON(failedResponse.readAll()).message}
        })
    end

    return textutils.unserialiseJSON(handler.readAll())
end

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
        dependencies = meta.dependencies,
        nest = {}
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

        if (packageLOCK[cpath] and areCompatible(packageLOCK[cpath].version, prefix .. package.version)) then
            return;
        end
    end

    local nestLevel = 0
    for i = 0, #treeDir do
        local cpath = treeDirToLockLocation(firstN(treeDir, i), package.name)

        if (not packageLOCK[cpath]) then
            nestLevel = i
            break
        end
    end

    -- * Download path
    local dpath = firstN(treeDir, nestLevel)

    if nestLevel > 0 then
        local nest = depTree[dpath[1]].nest
        for i = 2, #dpath do
            nest = nest[dpath[i]].nest
        end
        nest[package.name] = package
    else
        depTree[package.name] = package
    end

    packageLOCK[treeDirToLockLocation(dpath, package.name)] = {
        name = package.name,
        version = package.version,
        dependencies = package.dependencies
    }
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
    local prefix = splitSemVer(version)
    local meta = getPackageMeta(name, version)

    addToDepTree(packageLOCK, depTree, treeDir, metaToEntry(meta), prefix)

    table.insert(treeDir, meta.name)
    for name, version in sortAlphabetically(meta.dependencies) do
        generateDepTree(packageLOCK, name .. "@" .. version, depTree, treeDir)
    end
    table.remove(treeDir)

    return depTree
end

local packageLockPath = "/package-lock.json"
local packageJsonPath = "/package.json"

local function installDependency(installPath, name, version)
    local handler, errMessage, failedResponse = http.get("http://localhost:3000/packages/" .. name .. "?version=" ..
                                                             version)

    if (errMessage) then
        if not failedResponse then
            error({
                message = {"Server is down. Please try again later!"}
            })
        end

        error({
            message = {failedResponse.getResponseCode() .. " " ..
                textutils.unserialiseJSON(failedResponse.readAll()).message}
        })
    end

    local response = textutils.unserialiseJSON(handler.readAll())

    for key, value in pairs(response.package) do
        if key ~= "package.json" and key ~= "package-lock.json" then
            local installPath = fs.combine(installPath, key)

            print("  => Unpacking " .. key)
            local writer = fs.open(installPath, "w")
            writer.write(value)
            writer.close()
        end
    end
end

local function installDepTree(root, branch, nest)
    nest = nest or {}

    for path, data in pairs(branch) do
        print("Installing " .. path .. " v" .. data.version)
        installDependency(root .. "/" .. asPath(nest) .. "/" .. path, data.name, data.version)
        installDepTree(root, data.nest, addToEnd(nest, path))
    end
end

local function install(args)
    if #args < 2 then
        error({
            message = {"1 argument expected", "Correct usage: luam install <name>[@version]"}
        })
    end

    -- * Package directory
    local pdir = findPackageDir()

    local packageLOCK = fs.exists(pdir .. packageLockPath) and decodeFromFile(pdir .. packageLockPath) or {}
    local packageJSON = fs.exists(pdir .. packageJsonPath) and decodeFromFile(pdir .. packageJsonPath) or {}

    local name, version = splitByAtSymbol(args[2])

    if not version then
        local meta = getPackageMeta(name, version)
        version = meta.version
    end

    local packagesToInstall = generateDepTree(packageLOCK, name .. "@" .. version)

    installDepTree(pdir .. "/luam_modules", packagesToInstall)

    if not packageJSON.dependencies then
        packageJSON.dependencies = {}
    end

    packageJSON.dependencies[name] = version

    fs.open(fs.combine(pdir, "package.json"), "w").write(encodePretty(packageJSON))
    fs.open(fs.combine(pdir, "package-lock.json"), "w").write(encodePretty(packageLOCK))
end

return install
