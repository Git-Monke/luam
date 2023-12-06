require ".tableutils.lib"

local function join(version, meta)
    if version and not meta then
        return "?version=" .. version
    end
    if meta and not version then
        return "?meta=true"
    end
    if not (meta and version) then
        return ""
    end
    return "?version=" .. version .. "&" .. "meta=true"
end

local function getPackage(name, version, metaonly)
    local handler, errMessage, failedResponse = http.get("http://localhost:3000/packages/" .. name ..
        join(version, metaonly))

    if (errMessage) then
        if not failedResponse then
            error({
                message = { "Server is down. Please try again later!" }
            })
        end

        -- error({
        --     message = {failedResponse.getResponseCode() .. " " ..
        --         textutils.unserialiseJSON(failedResponse.readAll()).message}
        -- })
        return nil, failedResponse.getResponseCode()
    end

    return textutils.unserialiseJSON(handler.readAll()), handler.getResponseCode()
end

return getPackage
