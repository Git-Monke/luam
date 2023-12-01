local pretty = require "cc.pretty"

local function splitSemVer(ver)
    local prefix, major, minor, patch = ver:match("^([~^]?)(%d+)%.(%d+)%.(%d+)")
    return prefix, {tonumber(major), tonumber(minor), tonumber(patch)}
end

local function toSemVer(ma, mi, pa)
    return ma .. "." .. mi .. "." .. pa
end

local function checkCompatability(v1, v2)
    local _, v1components = splitSemVer(v1)
    local prefix, v2components = splitSemVer(v2)

    if prefix == "~" then

        return v2components[3] <= v1components[3] and v2components[2] == v1components[2] and v2components[1] ==
                   v1components[1]
    end

    if prefix == "^" then
        return v2components[2] <= v1components[2] and v2components[1] == v1components[1]
    end

    return v1 == v2
end

return {
    checkCompatability = checkCompatability,
    splitSemVer = splitSemVer
}

