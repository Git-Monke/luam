require ".luam.commands.json"
local semver = require ".luam.commands.install.semver"

local pretty = require("cc.pretty")

--
--  Takes an (already parsed) package-lock.json, a target package, and its version number
--  and finds every package in the dependency tree that depends on it.
--
--  @param {table} packageJSON - A parsed package-lock.json file as a table
--  @param {string} targetPackage - The name of the package to search for 
--  @param {string} targetVersion - The vesrion of the package to search for (in semantic versioning structure)
--  @return {table} - A list of the paths to the dependent modules
--
local function findDependentsFromPackageJSON(packageJSON, targetPackage, targetVersion)
    local dependents = {}

    for path, data in pairs(packageJSON) do
        for name, version in pairs(data.dependencies) do
            if name == targetPackage and semver.checkCompatability(version, targetVersion) then
                table.insert(dependents, path)
            end
        end
    end

    return dependents
end

pretty.pretty_print(findDependentsFromPackageJSON(decodeFromFile("/testing/package-lock.json"), "d", "^0.1.0"))

return findDependentsFromPackageJSON
