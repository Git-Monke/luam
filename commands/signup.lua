local pretty = require "cc.pretty"

local function signUp(args)
    if (#args < 2) then
        error({
            message = {"At least 2 arguments expected.", "Correct usage: luam signup <githubToken>",
                       "Run luam help signup for more details"}
        })
    end

    local body = {
        token = args[2]
    }
    local json = textutils.serialiseJSON(body)

    local response, errMessage, failedResponse = http.post("http://localhost:3000/users", json, {
        ["Content-Type"] = "application/json"
    })

    if (errMessage) then
        error({
            message = {failedResponse.getResponseCode(), textutils.unserialiseJSON(failedResponse.readAll()).message}
        })
    end

    local data = textutils.unserialiseJSON(response.readAll())

    print("\nWelcome to Luam " .. data.login .. "!\n")
    print("Your new auth token is " .. data.token)
    print("\nDO NOT LOSE OR SHARE THIS TOKEN. It will be used to verify your identity in the future\n")
    print(
        "You may run luam signup <gitToken> again to generate a new auth token in case you forget your current one, but only once every 24 hours.\n")
    print("* You are logged in automatically. To log into other computers, use luam login <authToken>")
    print("* To log out, use luam logout\n")

    fs.open("luam.key", "w").write(data.token)
end

return signUp
