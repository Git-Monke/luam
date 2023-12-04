require "commands.json"
local SemVer = require "commands.install.semver"
local getPackage = require "commands.install.getpackage"

local pretty = require "cc.pretty"

local ModuleTree = {
    packagePath = "",
    lockJsonPath = "",
    packageJsonPath = "",
    lock = {},
    package = {},
    fileRecord = {},
    trash = {}
}

local function firstN(tbl, n)
    local result = {}
    for i = 1, n do
        table.insert(result, tbl[i])
    end
    return result
end

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

local function split(str, delimiter)
    delimiter = delimiter or "/luam_modules/"
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

local function reverseTable(t)
    local reversedTable = {}
    local itemCount = #t
    for i = itemCount, 1, -1 do
        table.insert(reversedTable, t[i])
    end
    return reversedTable
end

function ModuleTree:new(packageDir)
    local packageDir = packageDir or shell.path()
    local new = {}
    setmetatable(new, {
        __index = ModuleTree
    });

    new.lockJsonPath = packageDir .. "/package-lock.json"
    new.packageJsonPath = packageDir .. "/package.json"
    new.packagePath = packageDir

    new.lock = fs.exists(new.lockJsonPath) and decodeFromFile(new.lockJsonPath) or {}
    new.package = fs.exists(new.packageJsonPath) and decodeFromFile(new.packageJsonPath) or {}
    new.trash = {}

    new.fileRecord = {}

    return new
end

function ModuleTree:commitChanges()
    local lockWriter = fs.open(self.lockJsonPath, "w")
    local packageWriter = fs.open(self.packageJsonPath, "w")

    lockWriter.write(encodePretty(self.lock))
    packageWriter.write(encodePretty(self.package))

    lockWriter.close()
    packageWriter.close()

    fs.delete(self.packagePath .. "/luam_modules/.trash")
end

--- Returns if the module even needs to be installed, and if so the valid installation location
-- For nest = {a, b} installing d, the search order will be as follows:
-- d, a/luam_modules/d, a/luam_modules/b/luam_modules/d etc.
function ModuleTree:findInstallationLocation(nest, packageName, packageVersion)
    local cpath = packageName

    if not self.lock[cpath] then
        return true, cpath
    end

    if self.lock[cpath] and SemVer.checkCompatability(self.lock[cpath].version, packageVersion) then
        return false
    end

    for i = 1, #nest do
        cpath = nest[i] .. "/luam_modules/" .. cpath

        if not self.lock[cpath] then
            print("Is this happening")
            return true, cpath
        end

        if self.lock[cpath] and SemVer.checkCompatability(self.lock[cpath].version, packageVersion) then
            return false
        end
    end

    error({
        message = {"No valid installation location."}
    })
end

--- Used for finding the package-lock.json path that a submodule is referring
-- "path" is where the search will be done relative to.
-- If the path is a/luam_modules/b/luam_modules/c and c depends on d@0.1.0,
-- The algorithm will search a, then a/lm/b. It will not search the package itself (c).
-- @return {bool, string} Returns true if it found a compatible package, and the path to that package. Otherwise returns false.
function ModuleTree:findModuleFromLocation(path, name, version)
    local nest = split(path, "/luam_modules/")

    for i = 0, #nest - 1 do
        local path = treeDirToLockLocation(firstN(nest, i), name)
        if self.lock[path] and SemVer.checkCompatability(self.lock[path].version, version) then
            return true, path
        end
    end

    return false
end

--- Returns a list of packages that depend on the target package in the form of an indexed table of tables with properties {version, path}
function ModuleTree:findAllDependents(packageName, packageVersion)
    local dependents = {}

    for path, data in pairs(self.lock) do
        for dependency, version in pairs(data.dependencies) do
            if dependency == packageName and SemVer.checkCompatability(version, packageVersion) then
                table.insert(dependents, {
                    path = path,
                    version = data.dependencies[packageName]
                })
            end
        end
    end

    return dependents
end

-- Performs deletion operations relative to the packages luam_modules folder
function ModuleTree:moveToTrash(path)
    local oldPath = self.packagePath .. "/luam_modules/" .. path
    local trashPath = self.packagePath .. "/luam_modules/.trash/" .. path

    self.trash[path] = self.lock[path]
    self.lock[path] = nil

    for modpath, data in pairs(self.lock) do
        if modpath:sub(1, #path) == path then
            self.trash[modpath] = data
            self.lock[modpath] = nil
        end
    end

    fs.move(oldPath, trashPath)

    table.insert(self.fileRecord, {
        operation = "delete",
        oldPath = oldPath,
        trashPath = trashPath
    })
end

--- If other modules depend on the module being deleted, it will not be deleted.
-- For forced deletion
-- @see ModuleTree:moveToTrash
function ModuleTree:deleteModule(path)
    local meta = self.lock[path]

    -- If deleting a top level dependency, check if the main package depends on it
    -- and remove it from the package dependencies
    if not path:find("/") then
        local packDependencies = self.package.dependencies
        if packDependencies[path] and SemVer.checkCompatability(packDependencies[path], meta.version) then
            self.package.dependencies[path] = nil
        end
    end

    if #self:findAllDependents(meta.name, meta.version) > 0 then
        return
    end

    self:moveToTrash(path)

    -- Attempts to delete all dependencies
    for dependency, version in pairs(meta.dependencies) do
        local foundPackage, packagePath = self:findModuleFromLocation(path, dependency, version)

        if foundPackage then
            ModuleTree.deleteModule(self, packagePath)
        end
    end
end

-- Warning: Does not check if it will overwrite a file. 
function ModuleTree:copyFromTrash(path, copyIntoPath)
    assert(path, "No path to copy from was provided")
    assert(copyIntoPath, "No path to copy into was provided")

    local oldPath = self.packagePath .. "/luam_modules/.trash/" .. path
    local newPath = self.packagePath .. "/luam_modules/" .. copyIntoPath

    self.lock[copyIntoPath] = self.trash[path]

    fs.copy(oldPath, newPath)

    table.insert(self.fileRecord, {
        operation = "copy",
        copiedFilePath = newPath
    })
end

--- Copies a directory from trash and then deletes its luam_modules folder
function ModuleTree:copyFromTrashExcludingSubmodules(path, copyIntoPath)
    self:copyFromTrash(path, copyIntoPath)
    print(self.packagePath .. "/luam_modules/" .. copyIntoPath .. "/luam_modules")
    fs.delete(self.packagePath .. "/luam_modules/" .. copyIntoPath .. "/luam_modules")
end

--- Tells the ModuleTree a new directory is created (allowing for reverting in case of errors)
-- Performs the operation relative to the /luam_modules directory of the package path
function ModuleTree:createDir(path)
    table.insert(self.fileRecord, {
        operation = "create",
        path = self.packagePath .. "/luam_modules/" .. path
    })
end

function ModuleTree:revertChanges()
    for _, change in ipairs(reverseTable(self.fileRecord)) do
        if change.operation == "copy" then
            fs.delete(change.copiedFilePath)
        end

        if change.operation == "delete" then
            -- Just in case something was put in its place
            fs.delete(change.oldPath)
            fs.copy(change.trashPath, change.oldPath)
        end

        if change.operation == "create" then
            fs.delete(change.path)
        end
    end

    fs.delete(self.packagePath .. "/luam_modules/.trash")
end

function ModuleTree:installModule(path, name, version)
    local data, code = getPackage(name, version)

    if code == 404 then
        error({
            message = {"404 Module Not Found"}
        })
    end

    self:createDir(path)

    self.lock[path] = {
        name = name,
        version = data.version,
        dependencies = data.dependencies
    }

    for filePath, fileData in pairs(data.package) do
        if not (filePath == "package.json" or filePath == "package-lock.json") then
            print("   => Unpacking " .. filePath)
            local writer = fs.open(self.packagePath .. "/luam_modules/" .. path .. "/" .. filePath, "w")
            writer.write(fileData)
            writer.close()
        end
    end
end

return ModuleTree
