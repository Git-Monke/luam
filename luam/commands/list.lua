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
        error({
            message = {"No luam_modules folder found!"}
        })
    end

    return asPath(components)
end

local function listPackagesInDir(dir, spacing)
    spacing = spacing or "  "
    local files = fs.list(dir)

    for _, file in ipairs(files) do
        if fs.isDir(fs.combine(dir, file)) then

        end
    end
end

local function list()
    local pdir = findPackageDir()

    listPackagesInModules(pdir)
end

return list
