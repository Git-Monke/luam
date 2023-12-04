local function login(args)
    if #args < 2 then
        error({
            message = {"An auth token is required to log in", "Correct usage: luam login <authToken>",
                       "These can be generated via luam signup <gitToken>",
                       "Run luam help login or luam help signup for more details"}
        })
    end

    local reader = fs.open("luam.key", "w")
    fs.open("luam.key", "w").write(args[2])
    term.clear()
    term.setCursorPos(1, 1)
    print("Logged in. Terminal cleared for security.")
end

local function logout(args)
    fs.delete("luam.key")
end

return {
    login = login,
    logout = logout
}
